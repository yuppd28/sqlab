USE AviationDB;
GO

DELETE FROM dbo.booking;
DELETE FROM dbo.booking_agency;
DELETE FROM dbo.passenger;
DELETE FROM dbo.flight;
DELETE FROM dbo.airport;
DELETE FROM dbo.plane;
DELETE FROM dbo.airline;


DBCC CHECKIDENT ('dbo.airline',        RESEED, 0);
DBCC CHECKIDENT ('dbo.plane',          RESEED, 0);
DBCC CHECKIDENT ('dbo.airport',        RESEED, 0);
DBCC CHECKIDENT ('dbo.flight',         RESEED, 0);
DBCC CHECKIDENT ('dbo.passenger',      RESEED, 0);
DBCC CHECKIDENT ('dbo.booking_agency', RESEED, 0);


INSERT INTO dbo.airline(name) VALUES (N'SkyWays'),(N'CargoJet');

INSERT INTO dbo.plane(airline_id, model, seat_capacity, kind) VALUES
  (1,N'Boeing 737-800',180,N'passenger'),
  (2,N'Boeing 767F',    2,N'cargo');

INSERT INTO dbo.airport(name, city) VALUES
  (N'Boryspil',N'Kyiv'),(N'Lviv Danylo Halytskyi',N'Lviv');

INSERT INTO dbo.flight(airline_id, plane_id, route, departs_at, depart_airport_id, arrive_airport_id)
VALUES (1,1,N'Kyiv → Lviv', DATEADD(DAY,2,SYSUTCDATETIME()), 1, 2);

INSERT INTO dbo.passenger(full_name) VALUES (N'Іван Петренко'),(N'Олена Сидоренко');
INSERT INTO dbo.booking_agency(name) VALUES (N'Aviatour'),(N'BestTickets');

INSERT INTO dbo.booking(passenger_id, flight_id, agency_id, seat_no)
VALUES (1,1,1,12),(2,1,2,13);

SELECT * FROM dbo.airline;
SELECT * FROM dbo.plane;
SELECT * FROM dbo.airport;
SELECT * FROM dbo.flight;
SELECT * FROM dbo.passenger;
SELECT * FROM dbo.booking_agency;
SELECT * FROM dbo.booking;
