import { INestApplication, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthController } from '../src/auth/auth.controller';
import { AuthService } from '../src/auth/auth.service';
import { JwtAuthGuard } from '../src/auth/jwt-auth.guard';
import { PrismaService } from '../src/prisma/prisma.service';

const testSecret = 'test-secret-that-is-long-enough-for-jwt-signing';

type TestUser = {
  id: string;
  email: string;
  passwordHash: string;
  createdAt: Date;
};

describe('Auth endpoints', () => {
  let app: INestApplication;
  const users: TestUser[] = [];
  const prismaMock = {
    user: {
      create: jest.fn(
        async ({
          data,
        }: {
          data: Pick<TestUser, 'email' | 'passwordHash'>;
        }) => {
          if (users.some((user) => user.email === data.email)) {
            throw Object.assign(new Error('Duplicate email'), {
              code: 'P2002',
            });
          }
          const user = {
            id: '6d83c821-72f8-45a7-b38b-43c9161fe6ac',
            ...data,
            createdAt: new Date('2026-01-01T00:00:00.000Z'),
          };
          users.push(user);
          return { id: user.id, email: user.email, createdAt: user.createdAt };
        },
      ),
      findUnique: jest.fn(
        async ({
          where,
          select,
        }: {
          where: { id?: string; email?: string };
          select?: { id?: boolean; email?: boolean; createdAt?: boolean };
        }) => {
          const user =
            users.find(
              (entry) => entry.id === where.id || entry.email === where.email,
            ) ?? null;
          if (!user || !select) return user;
          return { id: user.id, email: user.email, createdAt: user.createdAt };
        },
      ),
    },
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        AuthService,
        JwtAuthGuard,
        {
          provide: JwtService,
          useValue: new JwtService({ secret: testSecret }),
        },
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  beforeEach(() => {
    users.length = 0;
  });

  afterAll(async () => {
    await app.close();
  });

  it('registers a user, logs in, and returns the authenticated profile', async () => {
    const registration = await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        email: 'New.User@example.com',
        password: 'correct horse battery',
      })
      .expect(201);

    expect(registration.body.user.email).toBe('new.user@example.com');
    expect(registration.body.user.passwordHash).toBeUndefined();
    expect(registration.body.accessToken).toEqual(expect.any(String));

    const login = await request(app.getHttpServer())
      .post('/auth/login')
      .send({
        email: 'NEW.USER@example.com',
        password: 'correct horse battery',
      })
      .expect(201);

    const profile = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);

    expect(profile.body).toMatchObject({
      id: registration.body.user.id,
      email: 'new.user@example.com',
    });
    expect(profile.body.passwordHash).toBeUndefined();
  });

  it('rejects duplicate registrations and incorrect passwords', async () => {
    const credentials = {
      email: 'person@example.com',
      password: 'a longer password',
    };
    await request(app.getHttpServer())
      .post('/auth/register')
      .send(credentials)
      .expect(201);
    await request(app.getHttpServer())
      .post('/auth/register')
      .send(credentials)
      .expect(409);
    await request(app.getHttpServer())
      .post('/auth/login')
      .send({ ...credentials, password: 'not the right password' })
      .expect(401);
  });

  it('rejects requests to /me without a bearer token', async () => {
    await request(app.getHttpServer()).get('/auth/me').expect(401);
  });

  it('validates registration input', async () => {
    await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'not-an-email', password: 'short' })
      .expect(400);
  });
});
