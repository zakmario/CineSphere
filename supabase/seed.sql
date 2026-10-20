-- CinéSphère — données de référence (genres TMDB fr-FR, plateformes FR).
-- Généré depuis l'API TMDB le 2026-10-20. Rejouable.

begin;

insert into public.genres (id, name) values
  (12, 'Aventure'),
  (14, 'Fantastique'),
  (16, 'Animation'),
  (18, 'Drame'),
  (27, 'Horreur'),
  (28, 'Action'),
  (35, 'Comédie'),
  (36, 'Histoire'),
  (37, 'Western'),
  (53, 'Thriller'),
  (80, 'Crime'),
  (99, 'Documentaire'),
  (878, 'Science-Fiction'),
  (9648, 'Mystère'),
  (10402, 'Musique'),
  (10749, 'Romance'),
  (10751, 'Familial'),
  (10752, 'Guerre'),
  (10759, 'Action & Adventure'),
  (10762, 'Kids'),
  (10763, 'News'),
  (10764, 'Reality'),
  (10765, 'Science-Fiction & Fantastique'),
  (10766, 'Soap'),
  (10767, 'Talk'),
  (10768, 'War & Politics'),
  (10770, 'Téléfilm')
on conflict (id) do update set name = excluded.name;

-- id = identifiant fournisseur TMDB ; noms alignés sur media.platforms.
insert into public.platforms (id, name, logo_url) values
  (0, 'Cinéma', null),
  (8, 'Netflix', 'https://image.tmdb.org/t/p/w92/rK1KljqmbvO9HQa1PBFLILWah72.png'),
  (119, 'Prime Video', 'https://image.tmdb.org/t/p/w92/gMZdpavHmxFNnLpMHwVxfqeux2g.png'),
  (337, 'Disney+', 'https://image.tmdb.org/t/p/w92/5eZ872CghnHFLB1j8grszbrx0dx.png'),
  (350, 'Apple TV+', 'https://image.tmdb.org/t/p/w92/9icYBfYFcwgCbky5VdGUIKJ4C5i.png'),
  (1899, 'Max', 'https://image.tmdb.org/t/p/w92/skypuy7SXuugIQeYg0IglmzoKaS.png'),
  (381, 'Canal+', 'https://image.tmdb.org/t/p/w92/gliWKhLJVdm7QwL1braBCRko5dx.png'),
  (531, 'Paramount+', 'https://image.tmdb.org/t/p/w92/pkx3klJlwW5JdtaulvDx6hDNtch.png'),
  (283, 'Crunchyroll', 'https://image.tmdb.org/t/p/w92/uFL3c4Cq8M6WoLymlC5Y8bmGytV.png'),
  (234, 'Arte', 'https://image.tmdb.org/t/p/w92/ieo2l4zOaljYqJNGxWY8jWryld5.png'),
  (1754, 'TF1+', 'https://image.tmdb.org/t/p/w92/j5w5U61YwOM6Adiaa5zuEVqrpP8.png')
on conflict (id) do update set name = excluded.name, logo_url = excluded.logo_url;

commit;
