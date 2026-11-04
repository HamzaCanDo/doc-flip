<?php

namespace Tests\Unit;

use App\Services\GoogleDocConverter;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;

class GoogleDocConverterTest extends TestCase
{
    #[DataProvider('validGoogleUrlProvider')]
    public function test_it_extracts_file_ids_from_supported_google_hosts(string $url): void
    {
        $converter = new GoogleDocConverter;

        $this->assertSame('abcdefghijklmnop123', $converter->extractFileIdFromUrl($url));
    }

    public function test_it_rejects_non_google_hosts(): void
    {
        $converter = new GoogleDocConverter;

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Please provide a valid Google Docs URL.');

        $converter->extractFileIdFromUrl('https://example.com/document/d/abcdefghijklmnop123/edit');
    }

    public static function validGoogleUrlProvider(): array
    {
        return [
            'document' => ['https://docs.google.com/document/d/abcdefghijklmnop123/edit'],
            'spreadsheet' => ['https://docs.google.com/spreadsheets/d/abcdefghijklmnop123/edit'],
            'drive file' => ['https://drive.google.com/file/d/abcdefghijklmnop123/view'],
            'query id' => ['https://drive.google.com/open?id=abcdefghijklmnop123'],
        ];
    }
}
