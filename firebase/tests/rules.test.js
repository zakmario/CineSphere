// Tests des règles Firestore sur l'émulateur (cahier des charges, 5.7).
// Lancement : npm run test:rules (depuis firebase/).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

const ALICE = 'alice';
const BOB = 'bob';
const db = (uid) =>
  uid
    ? env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore()
    : env.unauthenticatedContext().firestore();

/** Écrit des données sans passer par les règles (préparation des tests). */
const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cinesphere',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (d) => {
    await setDoc(doc(d, 'users', ALICE), { username: 'alice', email: 'alice@example.com', role: 'user' });
    await setDoc(doc(d, 'users', BOB), { username: 'bob', email: 'bob@example.com', role: 'user' });
    await setDoc(doc(d, 'users', 'admin'), { username: 'admin', email: 'admin@example.com', role: 'admin' });
    await setDoc(doc(d, 'users', ALICE, 'favorites', 'movie_550'), { mediaType: 'movie', tmdbId: 550, title: 'Fight Club' });
    await setDoc(doc(d, 'users', ALICE, 'watchlists', 'w1'), { name: 'Privée', isPublic: false, itemCount: 1 });
    await setDoc(doc(d, 'users', ALICE, 'watchlists', 'w1', 'items', 'movie_550'), { title: 'Fight Club' });
    await setDoc(doc(d, 'users', ALICE, 'watchlists', 'w2'), { name: 'Publique', isPublic: true, itemCount: 1 });
    await setDoc(doc(d, 'users', ALICE, 'watchlists', 'w2', 'items', 'movie_550'), { title: 'Fight Club' });
    await setDoc(doc(d, 'usernames', 'alice'), { uid: ALICE });
    await setDoc(doc(d, 'movies', '550'), { tmdbId: 550, title: 'Fight Club', rating: 8.4 });
    await setDoc(doc(d, 'reviews', 'r1'), {
      userId: ALICE, mediaType: 'movie', tmdbId: 550, rating: 8, content: 'Culte',
      isPrivate: false, likesCount: 0,
    });
    await setDoc(doc(d, 'reviews', 'r2'), {
      userId: ALICE, mediaType: 'movie', tmdbId: 550, rating: 6, isPrivate: true, likesCount: 0,
    });
  });
});

describe('users', () => {
  it('lecture par un membre connecté, pas par un anonyme', async () => {
    await assertSucceeds(getDoc(doc(db(BOB), 'users', ALICE)));
    await assertFails(getDoc(doc(db(null), 'users', ALICE)));
  });

  it('création : son propre document, rôle user, e-mail du compte', async () => {
    const carol = db('carol');
    await assertFails(setDoc(doc(carol, 'users', 'carol'), { role: 'admin', email: 'carol@example.com' }));
    await assertFails(setDoc(doc(carol, 'users', 'carol'), { role: 'user', email: 'autre@example.com' }));
    await assertFails(setDoc(doc(carol, 'users', BOB), { role: 'user', email: 'carol@example.com' }));
    await assertSucceeds(setDoc(doc(carol, 'users', 'carol'), { role: 'user', email: 'carol@example.com' }));
  });

  it('le rôle ne change pas, un autre membre ne modifie rien', async () => {
    await assertFails(updateDoc(doc(db(ALICE), 'users', ALICE), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(db(ALICE), 'users', ALICE), { bio: 'Cinéphile' }));
    await assertFails(updateDoc(doc(db(BOB), 'users', ALICE), { bio: 'Piraté' }));
  });
});

describe('données privées', () => {
  it('favoris : propriétaire uniquement', async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), 'users', ALICE, 'favorites', 'movie_550')));
    await assertFails(getDoc(doc(db(BOB), 'users', ALICE, 'favorites', 'movie_550')));
    await assertFails(setDoc(doc(db(BOB), 'users', ALICE, 'favorites', 'movie_603'), { title: 'Matrix' }));
    await assertSucceeds(deleteDoc(doc(db(ALICE), 'users', ALICE, 'favorites', 'movie_550')));
  });

  for (const name of ['watched', 'notifications', 'searchHistory', 'history']) {
    it(`${name} : propriétaire uniquement`, async () => {
      await assertSucceeds(setDoc(doc(db(ALICE), 'users', ALICE, name, 'x'), { a: 1 }));
      await assertFails(getDoc(doc(db(BOB), 'users', ALICE, name, 'x')));
      await assertFails(setDoc(doc(db(BOB), 'users', ALICE, name, 'y'), { a: 1 }));
    });
  }
});

describe('listes', () => {
  it('privée : invisible pour les autres ; publique : lisible', async () => {
    await assertFails(getDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w1')));
    await assertFails(getDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w1', 'items', 'movie_550')));
    await assertSucceeds(getDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w2')));
    await assertSucceeds(getDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w2', 'items', 'movie_550')));
    await assertFails(getDoc(doc(db(null), 'users', ALICE, 'watchlists', 'w2')));
  });

  it('écriture par le propriétaire seulement, nom de 1 à 60 caractères', async () => {
    await assertFails(updateDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w2'), { name: 'Volée' }));
    await assertFails(setDoc(doc(db(BOB), 'users', ALICE, 'watchlists', 'w2', 'items', 'movie_13'), { title: 'x' }));
    await assertFails(setDoc(doc(db(ALICE), 'users', ALICE, 'watchlists', 'w3'), { name: '' }));
    await assertFails(setDoc(doc(db(ALICE), 'users', ALICE, 'watchlists', 'w3'), { name: 'x'.repeat(61) }));
    const alice = db(ALICE);
    const batch = writeBatch(alice);
    batch.set(doc(alice, 'users', ALICE, 'watchlists', 'w1', 'items', 'movie_13'), { title: 'Forrest Gump' });
    batch.update(doc(alice, 'users', ALICE, 'watchlists', 'w1'), { itemCount: increment(1) });
    await assertSucceeds(batch.commit());
  });
});

describe('usernames', () => {
  it('lecture par les membres connectés seulement', async () => {
    await assertSucceeds(getDoc(doc(db(BOB), 'usernames', 'alice')));
    await assertFails(getDoc(doc(db(null), 'usernames', 'alice')));
  });

  it('création si libre et à son nom ; ni modification ni vol', async () => {
    await assertFails(setDoc(doc(db(BOB), 'usernames', 'alice'), { uid: BOB }));
    await assertFails(setDoc(doc(db(BOB), 'usernames', 'bobby'), { uid: ALICE }));
    await assertSucceeds(setDoc(doc(db(BOB), 'usernames', 'bobby'), { uid: BOB }));
    await assertFails(setDoc(doc(db(BOB), 'usernames', 'bobby'), { uid: BOB, extra: 1 }));
    await assertFails(deleteDoc(doc(db(BOB), 'usernames', 'alice')));
    await assertSucceeds(deleteDoc(doc(db(ALICE), 'usernames', 'alice')));
  });
});

describe('reviews', () => {
  const review = (uid, extra = {}) => ({
    userId: uid, mediaType: 'movie', tmdbId: 550, rating: 7, content: 'Bien',
    isPrivate: false, likesCount: 0, createdAt: serverTimestamp(), ...extra,
  });

  it('avis privé : visible par son auteur seulement', async () => {
    await assertSucceeds(getDoc(doc(db(BOB), 'reviews', 'r1')));
    await assertFails(getDoc(doc(db(BOB), 'reviews', 'r2')));
    await assertSucceeds(getDoc(doc(db(ALICE), 'reviews', 'r2')));
  });

  it('création : à son nom, note 1-10, 2000 caractères, likesCount 0', async () => {
    await assertSucceeds(setDoc(doc(db(BOB), 'reviews', 'b1'), review(BOB)));
    await assertFails(setDoc(doc(db(BOB), 'reviews', 'b2'), review(ALICE)));
    await assertFails(setDoc(doc(db(BOB), 'reviews', 'b3'), review(BOB, { rating: 11 })));
    await assertFails(setDoc(doc(db(BOB), 'reviews', 'b4'), review(BOB, { rating: 0 })));
    await assertFails(setDoc(doc(db(BOB), 'reviews', 'b5'), review(BOB, { content: 'x'.repeat(2001) })));
    await assertFails(setDoc(doc(db(BOB), 'reviews', 'b6'), review(BOB, { likesCount: 5 })));
  });

  it('l\'auteur modifie son avis sans changer userId, mediaType, tmdbId', async () => {
    await assertSucceeds(updateDoc(doc(db(ALICE), 'reviews', 'r1'), { content: 'Chef-d\'œuvre', rating: 10 }));
    await assertFails(updateDoc(doc(db(ALICE), 'reviews', 'r1'), { tmdbId: 13 }));
    await assertFails(updateDoc(doc(db(ALICE), 'reviews', 'r1'), { userId: BOB }));
    await assertFails(deleteDoc(doc(db(BOB), 'reviews', 'r1')));
    await assertSucceeds(deleteDoc(doc(db(ALICE), 'reviews', 'r1')));
  });

  it('like : likes/{uid} + likesCount ±1 dans un lot ; rien d\'autre', async () => {
    const bob = db(BOB);
    const batch = writeBatch(bob);
    batch.set(doc(bob, 'reviews', 'r1', 'likes', BOB), { createdAt: serverTimestamp() });
    batch.update(doc(bob, 'reviews', 'r1'), { likesCount: increment(1) });
    await assertSucceeds(batch.commit());
    await assertFails(updateDoc(doc(bob, 'reviews', 'r1'), { likesCount: increment(2) }));
    await assertFails(updateDoc(doc(bob, 'reviews', 'r1'), { content: 'Modifié par Bob' }));
    await assertFails(setDoc(doc(bob, 'reviews', 'r1', 'likes', ALICE), { createdAt: serverTimestamp() }));
  });

  it('requêtes de l\'app : avis publics d\'un titre, et son propre avis', async () => {
    const reviews = (d, ...filters) => query(collection(d, 'reviews'), ...filters);
    const ofMovie = [where('mediaType', '==', 'movie'), where('tmdbId', '==', 550)];
    await assertSucceeds(getDocs(reviews(db(BOB), ...ofMovie, where('isPrivate', '==', false))));
    await assertSucceeds(getCountFromServer(reviews(db(BOB), ...ofMovie, where('isPrivate', '==', false))));
    await assertFails(getDocs(reviews(db(BOB), ...ofMovie)));
    await assertSucceeds(getDocs(reviews(db(ALICE), where('userId', '==', ALICE), ...ofMovie)));
    await assertFails(getDocs(reviews(db(BOB), where('userId', '==', ALICE), ...ofMovie)));
  });

  it('suppression d\'un avis liké : l\'auteur efface aussi les likes des autres', async () => {
    await seed((d) => setDoc(doc(d, 'reviews', 'r1', 'likes', BOB), { createdAt: serverTimestamp() }));
    const carol = db('carol');
    await assertFails(deleteDoc(doc(carol, 'reviews', 'r1', 'likes', BOB)));
    const alice = db(ALICE);
    const batch = writeBatch(alice);
    batch.delete(doc(alice, 'reviews', 'r1', 'likes', BOB));
    batch.delete(doc(alice, 'reviews', 'r1'));
    await assertSucceeds(batch.commit());
  });
});

describe('catalogue', () => {
  it('lecture par les membres connectés', async () => {
    await assertSucceeds(getDoc(doc(db(BOB), 'movies', '550')));
    await assertFails(getDoc(doc(db(null), 'movies', '550')));
  });

  it('cache TMDB : tmdbId = identifiant et champs valides', async () => {
    await assertSucceeds(setDoc(doc(db(BOB), 'movies', '603'), { tmdbId: 603, title: 'Matrix', rating: 8.2 }));
    await assertSucceeds(setDoc(doc(db(BOB), 'series', '1399'), { tmdbId: 1399, title: 'Game of Thrones' }));
    await assertFails(setDoc(doc(db(BOB), 'movies', '604'), { tmdbId: 603, title: 'Matrix' }));
    await assertFails(setDoc(doc(db(BOB), 'movies', '605'), { tmdbId: 605, title: '' }));
    await assertFails(setDoc(doc(db(BOB), 'movies', '606'), { tmdbId: 606, title: 'x', rating: 42 }));
    await assertFails(deleteDoc(doc(db(BOB), 'movies', '550')));
  });

  it('genres, plateformes, sorties : écriture réservée aux admins', async () => {
    for (const name of ['genres', 'platforms', 'releaseEvents']) {
      await assertFails(setDoc(doc(db(BOB), name, 'x'), { name: 'x' }));
      await assertSucceeds(setDoc(doc(db('admin'), name, 'x'), { name: 'x' }));
    }
  });
});

it('tout le reste est refusé', async () => {
  await assertFails(setDoc(doc(db(ALICE), 'secrets', 'x'), { a: 1 }));
  await assertFails(getDoc(doc(db(ALICE), 'media', 'x')));
});
