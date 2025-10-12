
SELECT * FROM dbo.airline;
SELECT * FROM dbo.plane;
SELECT * FROM dbo.passenger_plane;
SELECT * FROM dbo.cargo_plane;
SELECT * FROM dbo.airport;
SELECT * FROM dbo.flight;
SELECT * FROM dbo.passenger;
SELECT * FROM dbo.booking_agency;
SELECT * FROM dbo.booking;

IF DB_ID('AviationDB') IS NULL CREATE DATABASE AviationDB;
GO
USE AviationDB;
GO

IF OBJECT_ID('dbo.trg_booking_guard','TR') IS NOT NULL DROP TRIGGER dbo.trg_booking_guard;
IF OBJECT_ID('dbo.trg_flight_plane_airline_match','TR') IS NOT NULL DROP TRIGGER dbo.trg_flight_plane_airline_match;
IF OBJECT_ID('dbo.trg_passenger_plane_xor','TR')   IS NOT NULL DROP TRIGGER dbo.trg_passenger_plane_xor;
IF OBJECT_ID('dbo.trg_cargo_plane_xor','TR')       IS NOT NULL DROP TRIGGER dbo.trg_cargo_plane_xor;
GO

IF OBJECT_ID('dbo.booking',        'U') IS NOT NULL DROP TABLE dbo.booking;
IF OBJECT_ID('dbo.booking_agency', 'U') IS NOT NULL DROP TABLE dbo.booking_agency;
IF OBJECT_ID('dbo.passenger',      'U') IS NOT NULL DROP TABLE dbo.passenger;
IF OBJECT_ID('dbo.flight',         'U') IS NOT NULL DROP TABLE dbo.flight;
IF OBJECT_ID('dbo.airport',        'U') IS NOT NULL DROP TABLE dbo.airport;
IF OBJECT_ID('dbo.passenger_plane','U') IS NOT NULL DROP TABLE dbo.passenger_plane;
IF OBJECT_ID('dbo.cargo_plane',    'U') IS NOT NULL DROP TABLE dbo.cargo_plane;
IF OBJECT_ID('dbo.plane',          'U') IS NOT NULL DROP TABLE dbo.plane;
IF OBJECT_ID('dbo.airline',        'U') IS NOT NULL DROP TABLE dbo.airline;
GO

CREATE TABLE dbo.airline(
  airline_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  name NVARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE dbo.plane(
  plane_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  airline_id BIGINT NOT NULL REFERENCES dbo.airline(airline_id),
  model NVARCHAR(200) NOT NULL
);

CREATE TABLE dbo.passenger_plane(
  plane_id BIGINT PRIMARY KEY REFERENCES dbo.plane(plane_id) ON DELETE CASCADE,
  seat_capacity INT NOT NULL CHECK (seat_capacity > 0)
);

CREATE TABLE dbo.cargo_plane(
  plane_id BIGINT PRIMARY KEY REFERENCES dbo.plane(plane_id) ON DELETE CASCADE,
  tonnage DECIMAL(10,2) NOT NULL CHECK (tonnage > 0)
);

CREATE TABLE dbo.airport(
  airport_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  name NVARCHAR(200) NOT NULL,
  city NVARCHAR(200) NOT NULL
);

CREATE TABLE dbo.flight(
  flight_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  airline_id BIGINT NOT NULL REFERENCES dbo.airline(airline_id),
  plane_id   BIGINT NOT NULL REFERENCES dbo.plane(plane_id),
  route NVARCHAR(400) NOT NULL,
  departs_at DATETIME2(0) NOT NULL,
  depart_airport_id BIGINT NOT NULL REFERENCES dbo.airport(airport_id),
  arrive_airport_id BIGINT NOT NULL REFERENCES dbo.airport(airport_id),
  CONSTRAINT chk_flight_airports_diff CHECK (depart_airport_id <> arrive_airport_id)
);
CREATE INDEX IX_flight_departs_at ON dbo.flight(departs_at);
CREATE INDEX IX_flight_plane      ON dbo.flight(plane_id);

CREATE TABLE dbo.passenger(
  passenger_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  full_name NVARCHAR(200) NOT NULL
);

CREATE TABLE dbo.booking_agency(
  agency_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  name NVARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE dbo.booking(
  passenger_id BIGINT NOT NULL REFERENCES dbo.passenger(passenger_id) ON DELETE CASCADE,
  flight_id    BIGINT NOT NULL REFERENCES dbo.flight(flight_id)       ON DELETE CASCADE,
  agency_id    BIGINT NOT NULL REFERENCES dbo.booking_agency(agency_id),
  seat_no INT NULL,
  booked_at DATETIME2(0) NOT NULL CONSTRAINT DF_booking_booked_at DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT PK_booking PRIMARY KEY (passenger_id, flight_id, agency_id),
  CONSTRAINT UQ_booking_pf UNIQUE (passenger_id, flight_id),
  CONSTRAINT CHK_booking_seat CHECK (seat_no IS NULL OR seat_no > 0)
);
CREATE UNIQUE INDEX UQ_booking_flight_seat
  ON dbo.booking(flight_id, seat_no) WHERE seat_no IS NOT NULL;
GO

CREATE TRIGGER dbo.trg_flight_plane_airline_match
ON dbo.flight
AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (
    SELECT 1 FROM inserted i
    JOIN dbo.plane p ON p.plane_id = i.plane_id
    WHERE p.airline_id <> i.airline_id
  ) THROW 50001, 'Plane airline must match flight airline.', 1;
END
GO

CREATE TRIGGER dbo.trg_passenger_plane_xor
ON dbo.passenger_plane
AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i WHERE EXISTS(SELECT 1 FROM dbo.cargo_plane c WHERE c.plane_id = i.plane_id))
    THROW 50011, 'Plane cannot be both passenger and cargo.', 1;
END
GO

CREATE TRIGGER dbo.trg_cargo_plane_xor
ON dbo.cargo_plane
AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i WHERE EXISTS(SELECT 1 FROM dbo.passenger_plane p WHERE p.plane_id = i.plane_id))
    THROW 50012, 'Plane cannot be both cargo and passenger.', 1;
END
GO

CREATE TRIGGER dbo.trg_booking_guard
ON dbo.booking
AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;

  IF EXISTS (
    SELECT 1 FROM inserted i
    JOIN dbo.flight f ON f.flight_id = i.flight_id
    WHERE i.booked_at >= f.departs_at
  ) THROW 50002, 'Booking after departure is not allowed.', 1;

  -- 2) тільки пасажирські рейси
  IF EXISTS (
    SELECT 1 FROM inserted i
    JOIN dbo.flight f ON f.flight_id = i.flight_id
    LEFT JOIN dbo.passenger_plane pp ON pp.plane_id = f.plane_id
    WHERE pp.plane_id IS NULL
  ) THROW 50005, 'Cannot book seats on a cargo/non-passenger flight.', 1;

  IF EXISTS (
    SELECT 1 FROM inserted i
    JOIN dbo.flight f ON f.flight_id = i.flight_id
    JOIN dbo.passenger_plane pp ON pp.plane_id = f.plane_id
    CROSS APPLY (SELECT COUNT(*) cnt FROM dbo.booking b WHERE b.flight_id = i.flight_id) x
    WHERE x.cnt > pp.seat_capacity
  ) THROW 50003, 'Overbooking denied: capacity reached.', 1;

  IF EXISTS (
    SELECT 1 FROM inserted i
    JOIN dbo.flight f ON f.flight_id = i.flight_id
    JOIN dbo.passenger_plane pp ON pp.plane_id = f.plane_id
    WHERE i.seat_no IS NOT NULL AND i.seat_no > pp.seat_capacity
  ) THROW 50004, 'Seat number exceeds plane capacity.', 1;
END
GO

INSERT INTO dbo.airline(name) VALUES (N'SkyWays'),(N'CargoJet');

INSERT INTO dbo.plane(airline_id, model) VALUES
  (1, N'Boeing 737-800'),   -- id=1
  (2, N'Boeing 767F');      -- id=2

INSERT INTO dbo.passenger_plane(plane_id, seat_capacity) VALUES (1,180);
INSERT INTO dbo.cargo_plane(plane_id, tonnage)           VALUES (2,52.0);

INSERT INTO dbo.airport(name, city) VALUES
  (N'Boryspil', N'Kyiv'),
  (N'Lviv Danylo Halytskyi', N'Lviv');

INSERT INTO dbo.flight(airline_id, plane_id, route, departs_at, depart_airport_id, arrive_airport_id)
VALUES (1,1,N'Kyiv → Lviv', DATEADD(DAY,2,SYSUTCDATETIME()), 1, 2);

INSERT INTO dbo.passenger(full_name) VALUES (N'Іван Петренко'),(N'Олена Сидоренко');
INSERT INTO dbo.booking_agency(name) VALUES (N'Aviatour'),(N'BestTickets');

INSERT INTO dbo.booking(passenger_id, flight_id, agency_id, seat_no)
VALUES (1,1,1,12),(2,1,2,13);
