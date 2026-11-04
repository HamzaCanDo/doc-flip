<?php

namespace Tests\Feature;

use Tests\TestCase;

class DownloadAuthorizationTest extends TestCase
{
    public function test_google_download_requires_a_valid_signature(): void
    {
        $this->get('/download/abcdefghijklmnop123/pdf')
            ->assertForbidden();
    }

    public function test_upload_download_requires_a_valid_signature(): void
    {
        $this->get('/upload-download/00000000-0000-0000-0000-000000000000/pdf')
            ->assertForbidden();
    }
}
