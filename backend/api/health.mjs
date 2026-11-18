export function GET() {
  return Response.json(
    {
      ok: true,
      message: 'API EcoDiet disponible',
      timestamp: new Date().toISOString(),
    },
    {
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    },
  );
}