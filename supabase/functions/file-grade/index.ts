import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const jsonHeaders = { 'Content-Type': 'application/json' };

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

// Format file yang dapat diekstrak teksnya
const EXTRACTABLE_MIME_TYPES = new Set([
  'text/plain',
  'text/csv',
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

const EXTRACTABLE_EXTENSIONS = new Set(['txt', 'csv', 'pdf', 'docx']);

function isExtractable(mimeType: string | null, fileName: string | null): boolean {
  if (mimeType && EXTRACTABLE_MIME_TYPES.has(mimeType.toLowerCase())) return true;
  if (fileName) {
    const ext = fileName.split('.').pop()?.toLowerCase() ?? '';
    return EXTRACTABLE_EXTENSIONS.has(ext);
  }
  return false;
}

async function extractTextFromFile(
  fileBytes: Uint8Array,
  mimeType: string | null,
  fileName: string | null,
): Promise<string | null> {
  const mime = mimeType?.toLowerCase() ?? '';
  const ext = fileName?.split('.').pop()?.toLowerCase() ?? '';

  // TXT / CSV — langsung decode
  if (mime === 'text/plain' || mime === 'text/csv' || ext === 'txt' || ext === 'csv') {
    try {
      return new TextDecoder('utf-8').decode(fileBytes);
    } catch {
      return null;
    }
  }

  // PDF — ekstrak teks menggunakan string search sederhana (tanpa library tambahan)
  // Ini bukan parser PDF penuh, tapi cukup untuk teks yang ter-embed sebagai plain text dalam PDF
  if (mime === 'application/pdf' || ext === 'pdf') {
    try {
      const rawText = new TextDecoder('latin1').decode(fileBytes);
      // Cari teks di antara BT dan ET (Begin Text / End Text markers dalam PDF)
      const texts: string[] = [];
      const btEtPattern = /BT([\s\S]*?)ET/g;
      let match;
      while ((match = btEtPattern.exec(rawText)) !== null) {
        const block = match[1];
        // Ambil string dalam tanda kurung: (text)
        const strPattern = /\(([^)\\]*(\\.[^)\\]*)*)\)/g;
        let strMatch;
        while ((strMatch = strPattern.exec(block)) !== null) {
          const extracted = strMatch[1]
            .replace(/\\n/g, '\n')
            .replace(/\\r/g, '\r')
            .replace(/\\t/g, '\t')
            .replace(/\\\(/g, '(')
            .replace(/\\\)/g, ')')
            .replace(/\\\\/g, '\\');
          if (extracted.trim().length > 0) {
            texts.push(extracted);
          }
        }
      }
      const result = texts.join(' ').replace(/\s+/g, ' ').trim();
      return result.length > 20 ? result : null;
    } catch {
      return null;
    }
  }

  // DOCX — XML-based, bisa diparse tanpa library
  if (
    mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
    ext === 'docx'
  ) {
    try {
      // DOCX adalah ZIP. Tanpa library dekompresi, kita coba cari teks XML
      // yang ter-embed langsung (untuk DOCX yang sederhana/tidak ter-compress berat)
      const rawText = new TextDecoder('utf-8', { fatal: false }).decode(fileBytes);
      // Cari konten di dalam tag w:t (Word text runs)
      const wtPattern = /<w:t[^>]*>([^<]+)<\/w:t>/g;
      const texts: string[] = [];
      let match;
      while ((match = wtPattern.exec(rawText)) !== null) {
        const t = match[1].trim();
        if (t.length > 0) texts.push(t);
      }
      const result = texts.join(' ').replace(/\s+/g, ' ').trim();
      return result.length > 20 ? result : null;
    } catch {
      return null;
    }
  }

  return null;
}

async function callGemini(
  apiKey: string,
  fileText: string,
  criteria: string[],
  maxScore: number,
): Promise<{ score: number; feedback: string; details: Record<string, boolean> } | null> {
  const model = Deno.env.get('LLM_MODEL') ?? 'gemini-2.0-flash-lite';
  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const criteriaList = criteria.map((c, i) => `${i + 1}. ${c}`).join('\n');
  const prompt = `Kamu adalah penilai tugas sekolah yang objektif. Gunakan Bahasa Indonesia.

Isi dokumen siswa:
"""
${fileText.slice(0, 6000)}
"""

Kriteria penilaian yang harus ada dalam dokumen (${criteria.length} kriteria):
${criteriaList}

Skor maksimal: ${maxScore}

Evaluasi apakah setiap kriteria terpenuhi dalam dokumen siswa. Skor dihitung proporsional: (jumlah kriteria terpenuhi / total kriteria) × ${maxScore}.

Balas HANYA dengan JSON valid tanpa teks lain:
{
  "score": <angka 0-${maxScore}>,
  "feedback": "<ringkasan 2-4 kalimat hasil penilaian dalam Bahasa Indonesia>",
  "details": {${criteria.map((c) => `"${c}": <true/false>`).join(', ')}}
}`;

  let res: Response;
  try {
    res = await fetch(`${apiUrl}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.1, maxOutputTokens: 600 },
      }),
    });
  } catch (err: unknown) {
    console.error('Gemini fetch error:', err instanceof Error ? err.message : String(err));
    return null;
  }

  if (!res.ok) {
    console.error('Gemini API error:', res.status, await res.text().catch(() => ''));
    return null;
  }

  let data: Record<string, unknown>;
  try {
    data = await res.json() as Record<string, unknown>;
  } catch {
    return null;
  }

  const candidates = data?.candidates as Array<Record<string, unknown>> | undefined;
  const rawText = (
    ((candidates?.[0]?.content as Record<string, unknown>)?.parts as Array<Record<string, unknown>>)?.[0]?.text
  ) as string ?? '';

  // Strip markdown fences
  const cleaned = rawText.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/i, '').trim();

  try {
    const parsed = JSON.parse(cleaned) as { score: unknown; feedback: unknown; details: unknown };
    const score = Number(parsed.score);
    if (isNaN(score) || score < 0 || score > maxScore) return null;
    if (typeof parsed.feedback !== 'string') return null;
    const details = (parsed.details && typeof parsed.details === 'object')
      ? parsed.details as Record<string, boolean>
      : {};
    return {
      score: Math.round(score * 100) / 100,
      feedback: String(parsed.feedback).trim(),
      details,
    };
  } catch (err: unknown) {
    console.error('JSON parse error:', err instanceof Error ? err.message : String(err), 'raw:', cleaned);
    return null;
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        ...jsonHeaders,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
      },
    });
  }
  if (request.method !== 'POST') return response({ error: 'POST required' }, 405);

  const llmApiKey = Deno.env.get('LLM_API_KEY');
  if (!llmApiKey) {
    return response({ error: 'Fitur AI belum dikonfigurasi.', code: 'AI_NOT_CONFIGURED' }, 503);
  }

  // Auth
  const authorization = request.headers.get('authorization');
  if (!authorization?.toLowerCase().startsWith('bearer ')) {
    return response({ error: 'Authentication required' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return response({ error: 'Server is not configured' }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return response({ error: 'Invalid or expired token' }, 401);

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('id, role, status')
    .eq('id', userData.user.id)
    .maybeSingle();
  if (profileError || !profile || profile.status !== 'active') {
    return response({ error: 'Active profile not found' }, 401);
  }
  if (!['teacher', 'admin', 'superadmin'].includes(profile.role as string)) {
    return response({ error: 'Hanya teacher/admin/superadmin yang dapat menggunakan penilaian AI' }, 403);
  }

  // Parse request body
  let body: { submission_id?: string };
  try {
    body = await request.json() as { submission_id?: string };
  } catch {
    return response({ error: 'Request body tidak valid' }, 400);
  }

  const submissionId = body.submission_id;
  if (!submissionId || typeof submissionId !== 'string') {
    return response({ error: 'submission_id wajib diisi' }, 400);
  }

  // Ambil data submission
  const { data: submission, error: subError } = await adminClient
    .from('submissions')
    .select('id, file_path, file_name, mime_type, todo_id, todos(name, ai_criteria, submission_format)')
    .eq('id', submissionId)
    .maybeSingle();

  if (subError || !submission) {
    return response({ error: 'Submission tidak ditemukan' }, 404);
  }

  const filePath = submission.file_path as string | null;
  const fileName = submission.file_name as string | null;
  const mimeType = submission.mime_type as string | null;
  const todo = submission.todos as { name: string; ai_criteria: string[] | null; submission_format: string | null } | null;

  if (!filePath) {
    return response({ error: 'Submission ini tidak memiliki file' }, 422);
  }

  if (!isExtractable(mimeType, fileName)) {
    return response({
      error: `Format file tidak didukung untuk penilaian AI. Hanya PDF, DOCX, dan TXT yang dapat diproses. File: ${fileName ?? 'unknown'}`,
    }, 422);
  }

  const criteria: string[] = Array.isArray(todo?.ai_criteria) ? todo!.ai_criteria : [];
  if (criteria.length === 0) {
    return response({ error: 'Tugas ini belum memiliki kriteria penilaian AI. Tambahkan kriteria di pengaturan tugas.' }, 422);
  }

  // Download file dari Supabase Storage
  const bucket = 'assignment-submissions';
  const relativePath = filePath.startsWith(`${bucket}/`)
    ? filePath.slice(bucket.length + 1)
    : filePath;

  const { data: fileData, error: downloadError } = await adminClient.storage
    .from(bucket)
    .download(relativePath);

  if (downloadError || !fileData) {
    console.error('File download error:', downloadError);
    return response({ error: 'Gagal mengunduh file siswa dari storage' }, 500);
  }

  const fileBytes = new Uint8Array(await fileData.arrayBuffer());

  // Ekstrak teks dari file
  const extractedText = await extractTextFromFile(fileBytes, mimeType, fileName);
  if (!extractedText || extractedText.trim().length < 10) {
    return response({
      error: 'Teks tidak dapat diekstrak dari file ini. File mungkin berupa gambar scan atau format binary yang tidak didukung.',
    }, 422);
  }

  // Panggil Gemini AI
  const maxScore = 100;
  const aiResult = await callGemini(llmApiKey, extractedText, criteria, maxScore);
  if (!aiResult) {
    return response({ error: 'Gagal mendapat respons valid dari model AI. Coba lagi.' }, 500);
  }

  // Simpan grade ke database
  const now = new Date().toISOString();
  const { error: gradeError } = await adminClient.from('grades').upsert({
    submission_id: submissionId,
    grader_user_id: profile.id,
    score: aiResult.score,
    feedback: aiResult.feedback,
    ai_feedback: aiResult.feedback,
    source: 'ai',
    needs_review: true,
    graded_at: now,
  }, { onConflict: 'submission_id' });

  if (gradeError) {
    console.error('Grade save error:', gradeError);
    return response({ error: 'Gagal menyimpan hasil penilaian AI' }, 500);
  }

  await adminClient.from('submissions').update({ status: 'graded', updated_at: now }).eq('id', submissionId);

  await adminClient.rpc('log_audit_event', {
    p_action: 'AI_FILE_GRADING_RUN',
    p_description: `File AI grading: score=${aiResult.score}, submission=${submissionId}`,
    p_metadata: { score: aiResult.score, criteria_count: criteria.length },
  }).catch(() => {});

  return response({
    score: aiResult.score,
    feedback: aiResult.feedback,
    details: aiResult.details,
    submission_id: submissionId,
  });
});
