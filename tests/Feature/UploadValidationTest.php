<?php

namespace Tests\Feature;

use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class UploadValidationTest extends TestCase
{
    public function test_uploads_over_forty_megabytes_are_rejected_before_conversion(): void
    {
        $response = $this->postJson('/convert', [
            'file' => UploadedFile::fake()->create('document.docx', 40961),
            'upload_format' => 'pdf',
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonValidationErrors(['file']);
    }
}
