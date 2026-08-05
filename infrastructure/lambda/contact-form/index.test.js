jest.mock('@aws-sdk/client-ssm', () => ({
  SSMClient: jest.fn(),
  GetParameterCommand: jest.fn(),
}));

const setupEnvironment = () => {
  process.env.EMAILJS_SERVICE_ID = 'service_id';
  process.env.EMAILJS_TEMPLATE_ID = 'template_id';
  process.env.EMAILJS_PUBLIC_KEY = 'public_key';
  process.env.EMAILJS_PRIVATE_KEY = 'private_key';
  process.env.ALLOWED_ORIGINS = 'http://localhost:5173';
};

const createEvent = ({
  email = 'john@example.com',
  origin = 'http://localhost:5173',
} = {}) => ({
  httpMethod: 'POST',
  body: JSON.stringify({
    first: 'John',
    last: 'Doe',
    email,
    message: 'Hello',
  }),
  headers: {
    origin,
  },
});


describe('Contact Form Lambda', () => {
  let handler;
  let AWS;

  beforeEach(() => {
    jest.resetModules();

    setupEnvironment();

    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      text: jest.fn().mockResolvedValue('{}'),
    });

    AWS = require('@aws-sdk/client-ssm');

    AWS.SSMClient.mockImplementation(() => ({
      send: jest.fn().mockResolvedValue({
        Parameter: {
          Value: 'private_key',
        },
      }),
    }));

    handler = require('./index.js').handler;
  });


  afterEach(() => {
    jest.clearAllMocks();

    delete process.env.EMAILJS_SERVICE_ID;
    delete process.env.EMAILJS_TEMPLATE_ID;
    delete process.env.EMAILJS_PUBLIC_KEY;
    delete process.env.EMAILJS_PRIVATE_KEY;
    delete process.env.ALLOWED_ORIGINS;
  });


  test('should handle valid form submission', async () => {
    const result = await handler(createEvent());

    expect(result.statusCode).toBe(200);

    expect(JSON.parse(result.body)).toEqual({
      ok: true,
      message: 'Email sent successfully.',
    });

    expect(global.fetch).toHaveBeenCalledWith(
      'https://api.emailjs.com/api/v1.0/email/send',
      expect.objectContaining({
        method: 'POST',
      }),
    );
  });


  test('should return 400 for invalid email', async () => {
    const result = await handler(
      createEvent({
        email: 'invalid-email',
      }),
    );

    expect(result.statusCode).toBe(400);

    expect(JSON.parse(result.body)).toEqual({
      message: 'Invalid email address.',
    });

    expect(global.fetch).not.toHaveBeenCalled();
  });


  test('should throw when required environment variables are missing', () => {
    delete process.env.EMAILJS_SERVICE_ID;

    expect(() => {
      jest.resetModules();
      require('./index.js');
    }).toThrow(
      'Missing required environment variables: EMAILJS_SERVICE_ID',
    );
  });
});