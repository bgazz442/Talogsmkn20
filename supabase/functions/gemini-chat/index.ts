// gemini-chat — placeholder, belum diimplementasi
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (_request: Request) => {
  return new Response(
    JSON.stringify({ message: 'gemini-chat belum diimplementasi' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
