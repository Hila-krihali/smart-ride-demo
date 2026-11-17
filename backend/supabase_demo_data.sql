-- Safe Supabase demo data for the email-only MVP.
-- This script intentionally uses only UPSERTs. It does not delete, drop, or wipe data.

INSERT INTO public.users (
  id,
  first_name,
  last_name,
  phone_number,
  email,
  role,
  picture_url
) VALUES
  (1, 'Sara', 'Cohen', '050-1234567', 'sara@example.com', 'escort', NULL),
  (2, 'Rachel', 'Levi', '050-2345678', 'rachel@example.com', 'parent', NULL),
  (3, 'David', 'Mizrahi', '050-3456789', 'david@example.com', 'driver', NULL),
  (4, 'Yael', 'Avraham', '050-4567890', 'yael@example.com', 'manager', NULL),
  (5, 'Michal', 'Peretz', '050-5678901', 'michal@example.com', 'parent', NULL)
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  phone_number = EXCLUDED.phone_number,
  email = EXCLUDED.email,
  role = EXCLUDED.role,
  picture_url = EXCLUDED.picture_url;

INSERT INTO public.schools (
  id,
  name,
  address,
  latitude,
  longitude
) VALUES
  (1, 'Ofek School', 'Herzl 15, Beer Sheva', 31.2530, 34.7915),
  (2, 'Shachar Education Center', 'Bialik 8, Beer Sheva', 31.2500, 34.7890)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude;

INSERT INTO public.students (
  id,
  first_name,
  last_name,
  address,
  latitude,
  longitude,
  notes,
  mobility_status,
  parent_id,
  school_id,
  picture_url
) VALUES
  (1, 'Yossi', 'Levi', 'Rager 22, Beer Sheva', 31.2518, 34.7913, 'Sensitive to noise', 'regular', 2, 1, NULL),
  (2, 'Noa', 'Levi', 'Rager 22, Beer Sheva', 31.2518, 34.7913, 'Needs a calm reminder before boarding', 'regular', 2, 1, NULL),
  (3, 'Omer', 'Peretz', 'HaNasi 5, Beer Sheva', 31.2545, 34.7880, 'Needs help boarding', 'wheelchair', 5, 1, NULL),
  (4, 'Tamar', 'Dahan', 'Ben Gurion 30, Beer Sheva', 31.2490, 34.7950, 'Confirm parent is home at pickup time', 'regular', 2, 1, NULL),
  (5, 'Eitan', 'Azoulai', 'HaAtzmaut 12, Beer Sheva', 31.2560, 34.7870, 'Needs close escort at ride start', 'special escort', 5, 2, NULL),
  (6, 'Maia', 'Gabay', 'Keren Kayemet 7, Beer Sheva', 31.2475, 34.7935, 'Prefers window seat', 'regular', 5, 2, NULL)
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  address = EXCLUDED.address,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  notes = EXCLUDED.notes,
  mobility_status = EXCLUDED.mobility_status,
  parent_id = EXCLUDED.parent_id,
  school_id = EXCLUDED.school_id,
  picture_url = EXCLUDED.picture_url;

INSERT INTO public.parent_student (
  parent_id,
  student_id
) VALUES
  (2, 1),
  (2, 2),
  (2, 4),
  (5, 3),
  (5, 5),
  (5, 6)
ON CONFLICT (parent_id, student_id) DO NOTHING;

SELECT setval(
  pg_get_serial_sequence('public.parent_reports', 'id'),
  COALESCE((SELECT MAX(id) FROM public.parent_reports), 0) + 1,
  false
);
