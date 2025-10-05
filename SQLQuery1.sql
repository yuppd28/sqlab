IF DB_ID('AviationDB') IS NULL
BEGIN
  CREATE DATABASE AviationDB;
END
GO
USE AviationDB;
GO

IF OBJECT_ID('dbo.airline','U') IS NOT NULL DROP TABLE dbo.airline;
CREATE TABLE dbo.airline(
  airline_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  name NVARCHAR(200) NOT NULL UNIQUE
);

IF OBJECT_ID('dbo.plane','U') IS NOT NULL DROP TABLE dbo.plane;
CREATE TABLE dbo.plane(
  plane_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
  airline_id     BIGINT NOT NULL REFERENCES dbo.airline(airline_id),
  model          NVARCHAR(200) NOT NULL,
  seat_capacity  INT NOT NULL CHECK (seat_capacity > 0),
  kind           NVARCHAR(20) NOT NULL CHECK (kind IN (N'passenger', N'cargo'))  -- п≥дтип
);

IF OBJECT_ID('dbo.airport','U') IS NOT NULL DROP TABLE dbo.airport;
CREATE TABLE dbo.airport(
  airport_id   BIGINT IDENTITY(1,1) PRIMARY KEY,
  name         NVARCHAR(200) NOT NULL,
  city         NVARCHAR(200) NOT NULL
);

IF OBJECT_ID('dbo.flight','U') IS NOT NULL DROP TABLE dbo.flight;
CREATE TABLE dbo.flight(
  flight_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
  airline_id   BIGINT NOT NULL REFERENCES dbo.airline(airline_id),
  plane_id     BIGINT NOT NULL REFERENCES dbo.plane(plane_id),
  route        NVARCHAR(400) NOT NULL,
  departs_at   DATETIME2(0)  NOT NULL,          -- час в≥дправленн€ (UTC або локальний Ч на тв≥й виб≥р)
  depart_airport_id BIGINT NOT NULL REFERENCES dbo.airport(airport_id),
  arrive_airport_id BIGINT NOT NULL REFERENCES dbo.airport(airport_id),
  CONSTRAINT chk_flight_airports_diff CHECK (depart_airport_id <> arrive_airport_id)
);
CREATE INDEX IX_flight_departs_at ON dbo.flight(departs_at);
CREATE INDEX IX_flight_plane      ON dbo.flight(plane_id);

IF OBJECT_ID('dbo.passenger','U') IS NOT NULL DROP TABLE dbo.passenger;
CREATE TABLE dbo.passenger(
  passenger_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  full_name    NVARCHAR(200) NOT NULL
);

IF OBJECT_ID('dbo.booking_agency','U') IS NOT NULL DROP TABLE dbo.booking_agency;
CREATE TABLE dbo.booking_agency(
  agency_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
  name       NVARCHAR(200) NOT NULL UNIQUE
);

IF OBJECT_ID('dbo.booking','U') IS NOT NULL DROP TABLE dbo.booking;
GO
CREATE TABLE dbo.booking(
  passenger_id BIGINT NOT NULL REFERENCES dbo.passenger(passenger_id) ON DELETE CASCADE,
  flight_id    BIGINT NOT NULL REFERENCES dbo.flight(flight_id) ON DELETE CASCADE,
  agency_id    BIGINT NOT NULL REFERENCES dbo.booking_agency(agency_id),
  seat_no      INT NULL,
  booked_at    DATETIME2(0) NOT NULL CONSTRAINT DF_booking_booked_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT PK_booking PRIMARY KEY (passenger_id, flight_id, agency_id),
  CONSTRAINT UQ_booking_passenger_flight UNIQUE (passenger_id, flight_id),
  CONSTRAINT CHK_booking_seat_positive CHECK (seat_no IS NULL OR seat_no > 0)
);
GO
