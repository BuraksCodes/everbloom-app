/**
 * Everbloom API Proxy — Cloudflare Worker
 *
 * Routes:
 *   POST /tts          → ElevenLabs text-to-speech (returns MP3 bytes)
 *   POST /chat         → OpenAI chat completion  (streams SSE)
 *   POST /places       → Google Places API search (keeps API key server-side)
 *   POST /places/photo → Google Places photo proxy
 *
 * Security:
 *   Every request must include the header  X-App-Token: <your secret>
 *   Secrets stored as Worker Secrets via wrangler — never in source:
 *     wrangler secret put OPENAI_API_KEY
 *     wrangler secret put APP_TOKEN
 *     wrangler secret put GOOGLE_PLACES_API_KEY   ← NEW
 *
 * Rate limiting: 60 requests/minute per token (via in-memory counter)
 *
 * Deploy:
 *   1. wrangler secret put GOOGLE_PLACES_API_KEY  ← paste your AIzaSy... key
 *   2. wrangler deploy
 */

export default {
  async fetch(request, env) {
    // ── CORS preflight ────────────────────────────────────────────────────
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    // ── Authenticate every real request ───────────────────────────────────
    const token = request.headers.get('X-App-Token');
    if (!token || token !== env.APP_TOKEN) {
      return new Response('Unauthorized', { status: 401 });
    }

    // ── Simple in-memory rate limiting (resets per isolate lifetime) ──────
    const clientKey = token.slice(-8); // last 8 chars as a lightweight key
    const now = Date.now();
    if (!rateLimitMap.has(clientKey)) {
      rateLimitMap.set(clientKey, { count: 1, windowStart: now });
    } else {
      const entry = rateLimitMap.get(clientKey);
      if (now - entry.windowStart > 60_000) {
        // Reset window every minute
        entry.count = 1;
        entry.windowStart = now;
      } else {
        entry.count++;
        if (entry.count > 60) {
          return new Response('Too many requests', { status: 429 });
        }
      }
    }

    // ── Route ─────────────────────────────────────────────────────────────
    const { pathname } = new URL(request.url);

    if (pathname === '/tts' && request.method === 'POST') {
      return handleTTS(request, env);
    }
    if (pathname === '/chat' && request.method === 'POST') {
      return handleChat(request, env);
    }
    if (pathname === '/places' && request.method === 'POST') {
      return handlePlaces(request, env);
    }
    if (pathname === '/places/photo' && request.method === 'POST') {
      return handlePlacesPhoto(request, env);
    }

    return new Response('Not found', { status: 404 });
  },
};

// ── Rate limit state (in-memory, per isolate) ────────────────────────────────
const rateLimitMap = new Map();

// ── /tts ─────────────────────────────────────────────────────────────────────
// ElevenLabs text-to-speech proxy.
// Expects JSON body: { input: string, voice: string }
//   input — text to speak
//   voice — ElevenLabs voice ID (stored in the app, never hardcoded here)
// Returns raw MP3 bytes.

async function handleTTS(request, env) {
  let body;
  try { body = await request.json(); }
  catch { return new Response('Invalid JSON', { status: 400 }); }

  const text    = body.input || body.text || '';
  const voiceId = body.voice || 'jzuZ6QJQWqhEeMcPjdjx'; // fallback: British female therapist

  if (!text.trim()) {
    return new Response('Missing input text', { status: 400 });
  }

  const upstream = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: 'POST',
      headers: {
        'xi-api-key':   env.ELEVENLABS_API_KEY,
        'Content-Type': 'application/json',
        'Accept':       'audio/mpeg',
      },
      body: JSON.stringify({
        text,
        model_id: 'eleven_turbo_v2_5',
        voice_settings: {
          stability:        0.62,  // calm, consistent delivery
          similarity_boost: 0.80,  // close to original voice
          style:            0.0,   // no style exaggeration — therapeutic tone
          use_speaker_boost: true,
        },
      }),
    }
  );

  if (!upstream.ok) {
    const err = await upstream.text();
    console.error('[TTS error]', upstream.status, err);
    return new Response('Voice service temporarily unavailable', { status: upstream.status });
  }

  const audio = await upstream.arrayBuffer();
  return new Response(audio, {
    headers: {
      'Content-Type': 'audio/mpeg',
      ...corsHeaders(),
    },
  });
}

// ── /chat ─────────────────────────────────────────────────────────────────────
// Accepts the same JSON body as OpenAI's /v1/chat/completions.
// Passes the SSE stream straight through so the app's existing line-by-line
// reader keeps working without any changes.

async function handleChat(request, env) {
  let body;
  try { body = await request.json(); }
  catch { return new Response('Invalid JSON', { status: 400 }); }

  const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
    method:  'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!upstream.ok) {
    const err = await upstream.text();
    console.error('[Chat error]', upstream.status, err);
    return new Response('Chat service temporarily unavailable', { status: upstream.status });
  }

  // Stream the SSE response straight through to the app
  return new Response(upstream.body, {
    headers: {
      'Content-Type':  upstream.headers.get('Content-Type') ?? 'text/event-stream',
      'Cache-Control': 'no-cache',
      ...corsHeaders(),
    },
  });
}

// ── /places ───────────────────────────────────────────────────────────────────
// Proxies Google Places Nearby Search — keeps GOOGLE_PLACES_API_KEY server-side.
// Body: { url: "https://places.googleapis.com/..." , fieldMask: "...", body: {...} }

async function handlePlaces(request, env) {
  let payload;
  try { payload = await request.json(); }
  catch { return new Response('Invalid JSON', { status: 400 }); }

  const { url, fieldMask, body, method } = payload;
  if (!url || !url.startsWith('https://places.googleapis.com/')) {
    return new Response('Invalid places URL', { status: 400 });
  }

  const httpMethod = (method === 'GET') ? 'GET' : 'POST';
  const upstream = await fetch(url, {
    method: httpMethod,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': env.GOOGLE_PLACES_API_KEY,
      'X-Goog-FieldMask': fieldMask ?? '*',
    },
    // Only send a body for POST requests
    ...(httpMethod === 'POST' ? { body: JSON.stringify(body ?? {}) } : {}),
  });

  if (!upstream.ok) {
    const err = await upstream.text();
    console.error('[Places error]', upstream.status, err);
    return new Response('Places service temporarily unavailable', { status: upstream.status });
  }

  const data = await upstream.json();
  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

// ── /places/photo ─────────────────────────────────────────────────────────────
// Proxies Google Places photo bytes — keeps API key server-side.
// Body: { photoName: "places/.../photos/..." , maxWidthPx: 400 }

async function handlePlacesPhoto(request, env) {
  let payload;
  try { payload = await request.json(); }
  catch { return new Response('Invalid JSON', { status: 400 }); }

  const { photoName, maxWidthPx } = payload;
  if (!photoName || !photoName.startsWith('places/')) {
    return new Response('Invalid photo name', { status: 400 });
  }

  const photoURL = `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=${maxWidthPx ?? 400}&key=${env.GOOGLE_PLACES_API_KEY}`;
  const upstream = await fetch(photoURL);

  if (!upstream.ok) {
    console.error('[Places photo error]', upstream.status);
    return new Response('Photo unavailable', { status: upstream.status });
  }

  const imgData = await upstream.arrayBuffer();
  return new Response(imgData, {
    headers: {
      'Content-Type': upstream.headers.get('Content-Type') ?? 'image/jpeg',
      ...corsHeaders(),
    },
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-App-Token',
  };
}
