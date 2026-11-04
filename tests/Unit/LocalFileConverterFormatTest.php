<?php

namespace Tests\Unit;

use App\Services\LocalFileConverter;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use ReflectionClass;
use ReflectionMethod;

class LocalFileConverterFormatTest extends TestCase
{
    #[DataProvider('formatMatrixProvider')]
    public function test_upload_format_matrix(string $extension, array $expectedFormats): void
    {
        $converter = (new ReflectionClass(LocalFileConverter::class))->newInstanceWithoutConstructor();
        $method = new ReflectionMethod(LocalFileConverter::class, 'formatsForExtension');
        $method->setAccessible(true);

        $this->assertSame($expectedFormats, $method->invoke($converter, $extension));
    }

    public static function formatMatrixProvider(): array
    {
        return [
            'docx' => ['docx', ['pdf', 'xlsx', 'json', 'md']],
            'pdf' => ['pdf', ['xlsx', 'json', 'md']],
            'xlsx' => ['xlsx', ['pdf', 'json', 'md']],
            'unsupported' => ['doc', []],
        ];
    }
}
