#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${DEPLOYPATH:?DEPLOYPATH must be set by .cpanel.yml}"
PUBLIC_PATH="${PUBLICPATH:?PUBLICPATH must be set by .cpanel.yml}"
BACKUP_ROOT="$APP_PATH/.deploy-backups"
DEPLOYMENT_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_PATH="$BACKUP_ROOT/$DEPLOYMENT_ID"
LOCK_PATH="$APP_PATH/.deploy.lock"
MANIFEST_PATH="$BACKUP_PATH/.deployment-manifest"
DEPLOYMENT_STARTED=0

fail() {
    echo "Deployment stopped: $1" >&2
    exit 1
}

release_lock() {
    rmdir "$LOCK_PATH" 2>/dev/null || true
}

rollback() {
    local status=$?
    local entry
    local state
    local destination
    local backup

    if [ "$DEPLOYMENT_STARTED" -eq 1 ] && [ -f "$MANIFEST_PATH" ]; then
        trap - ERR
        while IFS='|' read -r state destination backup; do
            if [ "$state" = "existing" ]; then
                mkdir -p "$(dirname "$destination")"
                cp -p "$backup" "$destination"
            elif [ "$state" = "new" ]; then
                rm -f "$destination"
            fi
        done < "$MANIFEST_PATH"
        echo "Deployment failed; changed files were rolled back from $BACKUP_PATH." >&2
    fi

    return "$status"
}

backup_for_destination() {
    local destination="$1"

    if [[ "$destination" == "$APP_PATH/"* ]]; then
        printf '%s/%s\n' "$BACKUP_PATH" "${destination#"$APP_PATH"/}"
    else
        printf '%s/public/%s\n' "$BACKUP_PATH" "${destination#"$PUBLIC_PATH"/}"
    fi
}

if [ ! -d "$APP_PATH" ]; then
    fail "private application directory does not exist: $APP_PATH"
fi

if [ ! -d "$PUBLIC_PATH" ]; then
    fail "public application directory does not exist: $PUBLIC_PATH"
fi

if [ ! -w "$APP_PATH" ] || [ ! -w "$PUBLIC_PATH" ]; then
    fail "deployment user cannot write to the application or public directory"
fi

if [ ! -f "$APP_PATH/.env" ]; then
    fail "production .env is missing; deployment will not create or replace it"
fi

if [ ! -f "$APP_PATH/vendor/autoload.php" ]; then
    fail "production vendor/autoload.php is missing; install Composer dependencies manually first"
fi

if [ ! -f "$PUBLIC_PATH/index.php" ]; then
    fail "custom production public index.php is missing; deployment will not create it"
fi

if [ ! -f "$PUBLIC_PATH/.htaccess" ]; then
    fail "custom production .htaccess is missing; deployment will not create it"
fi

for composer_file in composer.json composer.lock; do
    [ -f "$REPO_ROOT/$composer_file" ] || fail "repository $composer_file is missing"
    [ -f "$APP_PATH/$composer_file" ] || fail "production $composer_file is missing; install dependencies manually and retry"
    if ! cmp -s "$REPO_ROOT/$composer_file" "$APP_PATH/$composer_file"; then
        fail "$composer_file differs from production; run Composer manually on cPanel and review before deploying this commit"
    fi
done

for directory in app config resources routes; do
    [ -d "$REPO_ROOT/$directory" ] || fail "required source directory is missing: $REPO_ROOT/$directory"
done
[ -f "$REPO_ROOT/bootstrap/app.php" ] || fail "required source file is missing: $REPO_ROOT/bootstrap/app.php"
[ -f "$REPO_ROOT/bootstrap/providers.php" ] || fail "required source file is missing: $REPO_ROOT/bootstrap/providers.php"
[ -d "$REPO_ROOT/database/migrations" ] || fail "required source directory is missing: $REPO_ROOT/database/migrations"
[ -f "$REPO_ROOT/artisan" ] || fail "required source file is missing: $REPO_ROOT/artisan"
for directory in assets build fonts; do
    [ -d "$REPO_ROOT/public/$directory" ] || fail "required public source directory is missing: $REPO_ROOT/public/$directory"
done
for file in favicon.ico robots.txt; do
    [ -f "$REPO_ROOT/public/$file" ] || fail "required public source file is missing: $REPO_ROOT/public/$file"
done

validate_tree() {
    local source_dir="$1"
    local source_file

    while IFS= read -r -d '' source_file; do
        [ -r "$source_file" ] || fail "required source file is not readable: $source_file"
    done < <(find "$source_dir" -type f -print0)
}

for directory in app config resources routes; do
    validate_tree "$REPO_ROOT/$directory"
done
validate_tree "$REPO_ROOT/database/migrations"
for directory in assets build fonts; do
    validate_tree "$REPO_ROOT/public/$directory"
done

for destination_root in "$APP_PATH" "$PUBLIC_PATH"; do
    [ -d "$destination_root" ] || fail "required destination directory is missing: $destination_root"
    [ -w "$destination_root" ] || fail "required destination directory is not writable: $destination_root"
done
case "$BACKUP_ROOT/" in
    "$PUBLIC_PATH/"*) fail "backup directory must remain outside the public directory: $BACKUP_ROOT" ;;
esac
for directory in app config resources routes database/migrations; do
    [ -d "$APP_PATH/$directory" ] || fail "required destination directory is missing: $APP_PATH/$directory"
done
for directory in assets build fonts; do
    [ -d "$PUBLIC_PATH/$directory" ] || fail "required destination directory is missing: $PUBLIC_PATH/$directory"
done

if ! mkdir "$LOCK_PATH" 2>/dev/null; then
    fail "another deployment is already running, or stale lock exists: $LOCK_PATH"
fi
trap release_lock EXIT
trap 'release_lock; exit 143' HUP INT TERM
trap rollback ERR

copy_file() {
    local source="$1"
    local destination="$2"

    if [ ! -f "$source" ]; then
        fail "required source file is missing: $source"
    fi

    mkdir -p "$(dirname "$destination")"
    if [ -d "$destination" ]; then
        fail "refusing to overwrite destination directory: $destination"
    fi
    local destination_mode=""
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        if [ -L "$destination" ]; then
            fail "refusing to overwrite destination symlink: $destination"
        fi
        destination_mode="$(stat -c '%a' "$destination")"
        printf 'existing|%s|%s\n' "$destination" "$(backup_for_destination "$destination")" >> "$MANIFEST_PATH"
    else
        printf 'new|%s|\n' "$destination" >> "$MANIFEST_PATH"
    fi
    cp -p "$source" "$destination"
    if [ -n "$destination_mode" ]; then
        chmod "$destination_mode" "$destination"
    fi
}

copy_tree() {
    local source_dir="$1"
    local destination_dir="$2"

    if [ ! -d "$source_dir" ]; then
        fail "required source directory is missing: $source_dir"
    fi

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"$source_dir"/}"
        copy_file "$source_file" "$destination_dir/$relative_path"
    done < <(find "$source_dir" -type f -print0)
}

backup_file() {
    local source="$1"
    local relative_path="$2"

    if [ -f "$source" ]; then
        mkdir -p "$(dirname "$BACKUP_PATH/$relative_path")"
        cp -p "$source" "$BACKUP_PATH/$relative_path"
    fi
}

mkdir -p "$BACKUP_PATH"

# Back up only files this deployment may overwrite. This excludes .env,
# storage, database data, vendor, public/index.php, and public/.htaccess.
for directory in app config resources routes; do
    if [ -d "$APP_PATH/$directory" ]; then
        while IFS= read -r -d '' source_file; do
            relative_path="${source_file#"$APP_PATH"/}"
            backup_file "$source_file" "$relative_path"
        done < <(find "$APP_PATH/$directory" -type f -print0)
    fi
done
backup_file "$APP_PATH/bootstrap/app.php" "bootstrap/app.php"
backup_file "$APP_PATH/bootstrap/providers.php" "bootstrap/providers.php"
while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$APP_PATH"/}"
    backup_file "$source_file" "$relative_path"
done < <(find "$APP_PATH/database/migrations" -type f -print0)
backup_file "$APP_PATH/artisan" "artisan"

for directory in assets build fonts; do
    if [ -d "$PUBLIC_PATH/$directory" ]; then
        while IFS= read -r -d '' source_file; do
            relative_path="${source_file#"$PUBLIC_PATH"/}"
            backup_file "$source_file" "public/$relative_path"
        done < <(find "$PUBLIC_PATH/$directory" -type f -print0)
    fi
done
backup_file "$PUBLIC_PATH/favicon.ico" "public/favicon.ico"
backup_file "$PUBLIC_PATH/robots.txt" "public/robots.txt"

# Application code and read-only project configuration. This never copies .env,
# storage, database data, vendor, or generated bootstrap cache files.
DEPLOYMENT_STARTED=1
for directory in app config resources routes; do
    copy_tree "$REPO_ROOT/$directory" "$APP_PATH/$directory"
done
copy_file "$REPO_ROOT/bootstrap/app.php" "$APP_PATH/bootstrap/app.php"
copy_file "$REPO_ROOT/bootstrap/providers.php" "$APP_PATH/bootstrap/providers.php"
copy_tree "$REPO_ROOT/database/migrations" "$APP_PATH/database/migrations"
copy_file "$REPO_ROOT/artisan" "$APP_PATH/artisan"

# Public assets and routing support. The existing production index.php and
# .htaccess are intentionally preserved because they contain host-specific
# paths and settings.
copy_tree "$REPO_ROOT/public/assets" "$PUBLIC_PATH/assets"
copy_tree "$REPO_ROOT/public/build" "$PUBLIC_PATH/build"
copy_tree "$REPO_ROOT/public/fonts" "$PUBLIC_PATH/fonts"
copy_file "$REPO_ROOT/public/favicon.ico" "$PUBLIC_PATH/favicon.ico"
copy_file "$REPO_ROOT/public/robots.txt" "$PUBLIC_PATH/robots.txt"

echo "DocFlip files deployed. Backup created at $BACKUP_PATH."
echo "Production .env, storage, database data, vendor, index.php, .htaccess, and Laravel caches were preserved."
echo "Run Laravel cache commands manually only after reviewing the deployed application."
