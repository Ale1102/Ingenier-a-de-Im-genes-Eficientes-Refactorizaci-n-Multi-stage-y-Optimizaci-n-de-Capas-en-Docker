<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    try {
        DB::connection()->getPdo();
        $database = 'up';
    } catch (\Throwable $e) {
        $database = 'down';
    }

    return response()->json([
        'status' => 'ok',
        'service' => 'laravel-api',
        'php' => PHP_VERSION,
        'database' => $database,
        'time' => now()->toIso8601String(),
    ], $database === 'up' ? 200 : 503);
});
