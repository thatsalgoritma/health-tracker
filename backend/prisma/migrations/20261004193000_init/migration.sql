-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "ImportStatus" AS ENUM ('QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "HealthRecordType" AS ENUM ('STEP_COUNT', 'DISTANCE', 'ACTIVE_ENERGY', 'HEART_RATE', 'RESTING_HEART_RATE', 'HRV', 'SLEEP_ANALYSIS', 'VO2_MAX');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "passwordHash" VARCHAR(255) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ImportJob" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "status" "ImportStatus" NOT NULL DEFAULT 'QUEUED',
    "progress" INTEGER NOT NULL DEFAULT 0,
    "recordsProcessed" INTEGER NOT NULL DEFAULT 0,
    "recordsSkipped" INTEGER NOT NULL DEFAULT 0,
    "workoutsProcessed" INTEGER NOT NULL DEFAULT 0,
    "recordsFailed" INTEGER NOT NULL DEFAULT 0,
    "errorMessage" TEXT,
    "fileName" VARCHAR(255) NOT NULL,
    "fileHash" CHAR(64) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ImportJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HealthRecord" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "type" "HealthRecordType" NOT NULL,
    "startDate" TIMESTAMPTZ(3) NOT NULL,
    "endDate" TIMESTAMPTZ(3) NOT NULL,
    "value" DOUBLE PRECISION,
    "valueText" VARCHAR(100),
    "unit" VARCHAR(50) NOT NULL,
    "sourceName" VARCHAR(255) NOT NULL,
    "dedupKey" CHAR(64) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HealthRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Workout" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "activityType" VARCHAR(100) NOT NULL,
    "startDate" TIMESTAMPTZ(3) NOT NULL,
    "endDate" TIMESTAMPTZ(3) NOT NULL,
    "durationSeconds" DOUBLE PRECISION NOT NULL,
    "distanceMeters" DOUBLE PRECISION,
    "energyKcal" DOUBLE PRECISION,
    "avgHeartRate" DOUBLE PRECISION,
    "sourceName" VARCHAR(255) NOT NULL,
    "dedupKey" CHAR(64) NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Workout_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "ImportJob_userId_status_createdAt_idx" ON "ImportJob"("userId", "status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ImportJob_userId_fileHash_key" ON "ImportJob"("userId", "fileHash");

-- CreateIndex
CREATE INDEX "HealthRecord_userId_type_startDate_idx" ON "HealthRecord"("userId", "type", "startDate");

-- CreateIndex
CREATE UNIQUE INDEX "HealthRecord_userId_dedupKey_key" ON "HealthRecord"("userId", "dedupKey");

-- CreateIndex
CREATE INDEX "Workout_userId_startDate_idx" ON "Workout"("userId", "startDate");

-- CreateIndex
CREATE INDEX "Workout_userId_activityType_startDate_idx" ON "Workout"("userId", "activityType", "startDate");

-- CreateIndex
CREATE UNIQUE INDEX "Workout_userId_dedupKey_key" ON "Workout"("userId", "dedupKey");

-- AddForeignKey
ALTER TABLE "ImportJob" ADD CONSTRAINT "ImportJob_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HealthRecord" ADD CONSTRAINT "HealthRecord_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Workout" ADD CONSTRAINT "Workout_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Sleep analysis records are categorical; all other selected record types are numeric.
ALTER TABLE "HealthRecord" ADD CONSTRAINT "HealthRecord_value_kind_check" CHECK (
  ("type" = 'SLEEP_ANALYSIS' AND "value" IS NULL AND "valueText" IS NOT NULL)
  OR
  ("type" <> 'SLEEP_ANALYSIS' AND "value" IS NOT NULL AND "valueText" IS NULL)
);

