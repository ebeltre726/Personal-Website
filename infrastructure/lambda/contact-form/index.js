const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

const ssmClient = new SSMClient({});
let privateKeyCache = null;

const REQUIRED_ENV_VARS = ['EMAILJS_SERVICE_ID', 'EMAILJS_TEMPLATE_ID', 'EMAILJS_PUBLIC_KEY', 'ALLOWED_ORIGINS'];

function validateRequiredEnvironment() {
  const missing = REQUIRED_ENV_VARS.filter((name) => !process.env[name]);

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  if (!process.env.EMAILJS_PRIVATE_KEY && !process.env.EMAILJS_PRIVATE_KEY_PARAMETER_NAME) {
    throw new Error('Missing EmailJS private key configuration. Set EMAILJS_PRIVATE_KEY or EMAILJS_PRIVATE_KEY_PARAMETER_NAME.');
  }
}

validateRequiredEnvironment();

async function getEmailJSPrivateKey() {
  if (privateKeyCache) {
    return privateKeyCache;
  }

  if (process.env.EMAILJS_PRIVATE_KEY) {
    privateKeyCache = process.env.EMAILJS_PRIVATE_KEY;
    return privateKeyCache;
  }

  const parameterName = process.env.EMAILJS_PRIVATE_KEY_PARAMETER_NAME;
  if (!parameterName) {
    throw new Error('EMAILJS_PRIVATE_KEY_PARAMETER_NAME is required when EMAILJS_PRIVATE_KEY is not set.');
  }

  const response = await ssmClient.send(
    new GetParameterCommand({
      Name: parameterName,
      WithDecryption: true
    })
  );

  privateKeyCache = response.Parameter?.Value;
  if (!privateKeyCache) {
    throw new Error(`Unable to retrieve EmailJS private key from parameter ${parameterName}.`);
  }

  return privateKeyCache;
}

function buildResponse(statusCode, body, origin, headers = {}) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Origin': getAllowedOrigin(origin),
      ...headers
    },
    body: typeof body === 'string' ? body : JSON.stringify(body)
  };
}

function getAllowedOrigin(requestOrigin = '') {
  const configuredOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:5173')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (requestOrigin && configuredOrigins.includes(requestOrigin)) {
    return requestOrigin;
  }

  return configuredOrigins[0] || 'http://localhost:5173';
}

exports.handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  const requestOrigin = event.headers?.origin || event.headers?.Origin || '';

  if (event.requestContext?.http?.method === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
    return buildResponse(200, '', requestOrigin);
  }

  if (!event.body) {
    return buildResponse(400, { message: 'Missing request body.' }, requestOrigin);
  }

  let body;
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch (error) {
    console.error('Error parsing JSON:', error);
    return buildResponse(400, { message: 'Invalid JSON format in request body.' }, requestOrigin);
  }

  const first = sanitizeInput(body.first);
  const last = sanitizeInput(body.last);
  const email = body.email ? body.email.trim() : '';
  const message = sanitizeInput(body.message);

  if (!validateEmail(email)) {
    return buildResponse(400, { message: 'Invalid email address.' }, requestOrigin);
  }

  const serviceId = process.env.EMAILJS_SERVICE_ID;
  const templateId = process.env.EMAILJS_TEMPLATE_ID;
  const publicKey = process.env.EMAILJS_PUBLIC_KEY;

  if (!serviceId || !templateId || !publicKey) {
    console.error('Missing EmailJS environment variables.');
    return buildResponse(500, { message: 'Email service is not configured.' }, requestOrigin);
  }

  try {
    const privateKey = await getEmailJSPrivateKey();
    const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        service_id: serviceId,
        template_id: templateId,
        user_id: publicKey,
        accessToken: privateKey,
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

    return buildResponse(200, { ok: true, message: 'Email sent successfully.' }, requestOrigin);
  } catch (error) {
    console.error(error);
    return buildResponse(500, { message: 'Failure sending email.' }, requestOrigin);
  }
};

function validateEmail(email) {
  const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
  return regex.test(email);
}

function sanitizeInput(input) {
  return input ? input.replace(/<\/?[^>]+(>|$)/g, '') : '';
}