<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\GeminiController;

Route::post('/gemini/answer', [GeminiController::class, 'generateAnswer']);
