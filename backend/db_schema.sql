-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.alerts (
  id integer NOT NULL DEFAULT nextval('alerts_id_seq'::regclass),
  ride_id integer,
  alert_type character varying NOT NULL,
  message text NOT NULL,
  severity character varying,
  status character varying,
  created_at timestamp without time zone,
  CONSTRAINT alerts_pkey PRIMARY KEY (id),
  CONSTRAINT alerts_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id)
);
CREATE TABLE public.attendance (
  id integer NOT NULL DEFAULT nextval('attendance_id_seq'::regclass),
  ride_id integer NOT NULL,
  student_id integer NOT NULL,
  status character varying NOT NULL,
  updated_by integer,
  updated_at timestamp without time zone,
  CONSTRAINT attendance_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id),
  CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT attendance_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id)
);
CREATE TABLE public.documents (
  id integer NOT NULL DEFAULT nextval('documents_id_seq'::regclass),
  owner_type character varying NOT NULL,
  owner_id integer,
  document_name character varying NOT NULL,
  document_url text NOT NULL,
  uploaded_at timestamp without time zone,
  CONSTRAINT documents_pkey PRIMARY KEY (id)
);
CREATE TABLE public.parent_reports (
  id integer NOT NULL DEFAULT nextval('parent_reports_id_seq'::regclass),
  parent_id integer NOT NULL,
  student_id integer NOT NULL,
  report_type character varying NOT NULL,
  start_date date NOT NULL,
  end_date date,
  message text,
  status character varying,
  created_at timestamp without time zone,
  CONSTRAINT parent_reports_pkey PRIMARY KEY (id),
  CONSTRAINT parent_reports_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.users(id),
  CONSTRAINT parent_reports_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id)
);
CREATE TABLE public.parent_student (
  parent_id integer NOT NULL,
  student_id integer NOT NULL,
  CONSTRAINT parent_student_pkey PRIMARY KEY (parent_id, student_id),
  CONSTRAINT parent_student_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.users(id),
  CONSTRAINT parent_student_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id)
);
CREATE TABLE public.ride_locations (
  id integer NOT NULL DEFAULT nextval('ride_locations_id_seq'::regclass),
  ride_id integer NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  recorded_at timestamp without time zone NOT NULL,
  CONSTRAINT ride_locations_pkey PRIMARY KEY (id),
  CONSTRAINT ride_locations_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id)
);
CREATE TABLE public.ride_students (
  id integer NOT NULL,
  ride_id integer NOT NULL,
  student_id integer NOT NULL,
  escort_id integer NOT NULL,
  is_going boolean,
  pickup_order integer,
  eta_minutes integer,
  status character varying,
  boarded_time timestamp without time zone,
  dropped_off_time timestamp without time zone,
  CONSTRAINT ride_students_pkey PRIMARY KEY (id),
  CONSTRAINT ride_students_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id),
  CONSTRAINT ride_students_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT ride_students_escort_id_fkey FOREIGN KEY (escort_id) REFERENCES public.users(id)
);
CREATE TABLE public.rides (
  id integer NOT NULL,
  route_id integer NOT NULL,
  ride_date date NOT NULL,
  status character varying,
  current_latitude numeric,
  current_longitude numeric,
  last_location_update timestamp without time zone,
  CONSTRAINT rides_pkey PRIMARY KEY (id),
  CONSTRAINT rides_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(id)
);
CREATE TABLE public.route_assignments (
  id integer NOT NULL,
  route_id integer NOT NULL,
  student_id integer NOT NULL,
  escort_id integer NOT NULL,
  default_pickup_order integer,
  CONSTRAINT route_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT route_assignments_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(id),
  CONSTRAINT route_assignments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT route_assignments_escort_id_fkey FOREIGN KEY (escort_id) REFERENCES public.users(id)
);
CREATE TABLE public.route_students (
  route_id integer NOT NULL,
  student_id integer NOT NULL,
  pickup_order integer,
  planned_pickup_time time without time zone,
  CONSTRAINT route_students_pkey PRIMARY KEY (route_id, student_id),
  CONSTRAINT route_students_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(id),
  CONSTRAINT route_students_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id)
);
CREATE TABLE public.routes (
  id integer NOT NULL,
  name character varying NOT NULL,
  direction character varying NOT NULL,
  planned_departure_time time without time zone NOT NULL,
  driver_id integer NOT NULL,
  vehicle_number character varying,
  vehicle_type character varying,
  status character varying,
  CONSTRAINT routes_pkey PRIMARY KEY (id),
  CONSTRAINT routes_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.users(id)
);
CREATE TABLE public.schools (
  id integer NOT NULL,
  name character varying NOT NULL,
  address character varying NOT NULL,
  latitude numeric,
  longitude numeric,
  CONSTRAINT schools_pkey PRIMARY KEY (id)
);
CREATE TABLE public.students (
  id integer NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  address character varying NOT NULL,
  latitude numeric,
  longitude numeric,
  notes character varying,
  mobility_status character varying,
  parent_id integer NOT NULL,
  school_id integer NOT NULL,
  picture_url character varying,
  CONSTRAINT students_pkey PRIMARY KEY (id),
  CONSTRAINT students_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.users(id),
  CONSTRAINT students_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id)
);
CREATE TABLE public.users (
  id integer NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  phone_number character varying,
  email character varying,
  role character varying NOT NULL,
  picture_url character varying,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.vehicles (
  id integer NOT NULL DEFAULT nextval('vehicles_id_seq'::regclass),
  vehicle_number character varying NOT NULL,
  vehicle_type character varying,
  seats_count integer,
  has_accessibility boolean,
  notes text,
  CONSTRAINT vehicles_pkey PRIMARY KEY (id)
);