<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

$olderThanMinutes = (int) config('services.upload_sweep_age_minutes', 60);
$olderThanMinutes = $olderThanMinutes > 0 ? $olderThanMinutes : 60;

Schedule::command('uploads:cleanup --older-than='.$olderThanMinutes)
    ->hourly();
