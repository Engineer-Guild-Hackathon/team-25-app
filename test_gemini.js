// Gemini APIテスト用スクリプト
const fetch = require('node-fetch');

const API_KEY = 'AIzaSyAcAgyzLJ2tTKTMlualOns8TnJP4Zp_U9A';
const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

async function testGeminiAPI() {
    try {
        console.log('Testing Gemini API...');

        const requestBody = {
            contents: [{
                parts: [{
                    text: "こんにちは。これは簡単なテストです。"
                }]
            }],
            generationConfig: {
                temperature: 0.3,
                maxOutputTokens: 100
            }
        };

        const response = await fetch(`${GEMINI_URL}?key=${API_KEY}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        console.log(`Response Status: ${response.status}`);
        console.log(`Response Status Text: ${response.statusText}`);

        if (response.ok) {
            const data = await response.json();
            console.log('Success! Response:', JSON.stringify(data, null, 2));
        } else {
            const errorText = await response.text();
            console.log('Error Response:', errorText);
        }

    } catch (error) {
        console.error('Request failed:', error.message);
    }
}

testGeminiAPI();