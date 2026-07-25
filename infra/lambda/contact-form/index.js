exports.handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  const corsHeaders = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Origin': getCorsOrigin(event.headers)
  };

  if (event.requestContext?.http?.method === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''
    };
  }

  if (!event.body) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Missing request body.' })
    };
  }

  let body;
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch (error) {
    console.error('Error parsing JSON:', error);
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Invalid JSON format in request body.' })
    };
  }

  const first = sanitizeInput(body.first);
  const last = sanitizeInput(body.last);
  const email = body.email ? body.email.trim() : '';
  const message = sanitizeInput(body.message);

  if (!validateEmail(email)) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Invalid email address.' })
    };
  }

  const serviceId = process.env.EMAILJS_SERVICE_ID;
  const templateId = process.env.EMAILJS_TEMPLATE_ID;
  const publicKey = process.env.EMAILJS_PUBLIC_KEY;

  if (!serviceId || !templateId || !publicKey) {
    console.error('Missing EmailJS environment variables.');
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Email service is not configured.' })
    };
  }

  try {
    const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        service_id: serviceId,
        template_id: templateId,
        user_id: publicKey,
        template_params: {
          user_firstname: first,
          user_lastname: last,
          user_email: email,
          user_message: message
        }
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`EmailJS Error: ${response.status} ${errorText}`);
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ ok: true, message: 'Email sent successfully.' })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Failure sending email.' })
    };
  }
};

function validateEmail(email) {
  const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
  return regex.test(email);
}

function sanitizeInput(input) {
  return input ? input.replace(/<\/?[^>]+(>|$)/g, '') : '';
}

function getCorsOrigin(headers = {}) {
  const origin = headers.origin || headers.Origin || '';
  const allowedOrigins = ['https://ebeltre.com', 'https://www.ebeltre.com', 'http://localhost:5173'];

  return allowedOrigins.includes(origin) ? origin : '*';
}