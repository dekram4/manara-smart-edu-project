<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class GeminiController extends Controller
{
    public function generateAnswer(Request $request)
    {
        $request->validate([
            'lesson' => 'required|string',
            'question' => 'required|string',
        ]);

        $lesson = $request->input('lesson');
        $question = $request->input('question');
        $apiKey = env('VITE_GEMINI_API_KEY');
        $url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={$apiKey}";

        $prompt = "أنت مساعد تعليمي متخصص في الرياضيات والعلوم. اقرأ النص التالي:\n\n{$lesson}\n\nالسؤال: {$question}\n\n⚠️ مهم: أجب من النص فقط، لا تضف معلومات خارجية.\nالآن أجب:";

        $response = Http::timeout(30)->post($url, [
            'contents' => [
                [ 'parts' => [ [ 'text' => $prompt ] ] ]
            ],
            'generationConfig' => [
                'temperature' => 0.2,
                'maxOutputTokens' => 150,
                'topP' => 0.8,
            ]
        ]);

        if ($response->successful()) {
            $data = $response->json();
            $answer = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
            return response()->json([
                'answer' => $answer,
                'raw' => $data
            ]);
        } else {
            return response()->json([
                'error' => 'فشل الاتصال بـ Gemini',
                'details' => $response->body()
            ], 500);
        }
    }
}
