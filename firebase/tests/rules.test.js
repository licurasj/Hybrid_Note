// Firestore security rules tests (T-14 unit 4, Q-8 B). They need the
// Firestore emulator: run them through `firebase emulators:exec` as the
// runbook shows, which sets FIRESTORE_EMULATOR_HOST.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  setLogLevel,
  writeBatch,
} from 'firebase/firestore';

const OWNER = 'owner-uid';
const OTHER = 'other-uid';

// Shaped like ListDefinition.toJson().
function list(id, extra = {}) {
  return {
    formatVersion: 1,
    id,
    name: 'Plants',
    icon: 'eco',
    color: '#4caf50',
    schemaRevision: 2,
    fields: [{ key: 'name', type: 'text', required: true, primary: true }],
    view: { kind: 'checklist' },
    behaviors: [],
    aiAllowed: true,
    updatedAt: '2026-03-01T00:00:00.000Z',
    ...extra,
  };
}

// Shaped like the store's item document: ListItem.toJson() plus `_rev`.
function item(id, listId, extra = {}) {
  return {
    id,
    listId,
    values: { name: 'fern' },
    createdAt: '2026-03-01T00:00:00.000Z',
    updatedAt: '2026-03-01T00:00:00.000Z',
    _rev: 2,
    ...extra,
  };
}

function without(data, key) {
  const copy = { ...data };
  delete copy[key];
  return copy;
}

let env;

before(async () => {
  // Denied writes are the expected outcome; keep the SDK from logging each.
  setLogLevel('silent');
  env = await initializeTestEnvironment({
    projectId: 'tac368-hybrid-note-app',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed as an admin: one list with one item in each user's tree.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of [OWNER, OTHER]) {
      await setDoc(doc(db, `users/${uid}/lists/plants`), list('plants'));
      await setDoc(doc(db, `users/${uid}/lists/plants/items/fern`), item('fern', 'plants'));
    }
  });
});

const owner = () => env.authenticatedContext(OWNER).firestore();
const other = () => env.authenticatedContext(OTHER).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();

describe('own tree', () => {
  test('the owner reads their lists and items, one by one and as queries', async () => {
    const db = owner();
    await assertSucceeds(getDoc(doc(db, `users/${OWNER}/lists/plants`)));
    await assertSucceeds(getDoc(doc(db, `users/${OWNER}/lists/plants/items/fern`)));
    await assertSucceeds(getDocs(collection(db, `users/${OWNER}/lists`)));
    await assertSucceeds(getDocs(collection(db, `users/${OWNER}/lists/plants/items`)));
  });

  test('the owner creates, updates and deletes a list', async () => {
    const ref = doc(owner(), `users/${OWNER}/lists/books`);
    await assertSucceeds(setDoc(ref, list('books')));
    await assertSucceeds(setDoc(ref, list('books', { schemaRevision: 3, name: 'Books' })));
    await assertSucceeds(deleteDoc(ref));
  });

  test('the owner creates, updates and deletes an item', async () => {
    const ref = doc(owner(), `users/${OWNER}/lists/plants/items/ivy`);
    await assertSucceeds(setDoc(ref, item('ivy', 'plants')));
    await assertSucceeds(setDoc(ref, item('ivy', 'plants', { _rev: 3 })));
    await assertSucceeds(deleteDoc(ref));
  });

  test('a list and its items in one batch, as createList writes them', async () => {
    const db = owner();
    const batch = writeBatch(db);
    batch.set(doc(db, `users/${OWNER}/lists/books`), list('books'));
    for (const id of ['b1', 'b2', 'b3']) {
      batch.set(doc(db, `users/${OWNER}/lists/books/items/${id}`), item(id, 'books'));
    }
    await assertSucceeds(batch.commit());
  });

  test('keys of a newer build on a list are allowed', async () => {
    const ref = doc(owner(), `users/${OWNER}/lists/books`);
    await assertSucceeds(setDoc(ref, list('books', { sortOrder: 4, archived: false })));
  });

  test('an item without `_rev` is allowed', async () => {
    const ref = doc(owner(), `users/${OWNER}/lists/plants/items/ivy`);
    await assertSucceeds(setDoc(ref, without(item('ivy', 'plants'), '_rev')));
  });

  test('hidden values with the nested-array encoding are allowed', async () => {
    const ref = doc(owner(), `users/${OWNER}/lists/plants/items/ivy`);
    await assertSucceeds(
      setDoc(
        ref,
        item('ivy', 'plants', {
          values: {
            name: 'ivy',
            tags: ['green', 'climbing'],
            _legacy: {
              tags: [{ __array: ['old', 'tags'] }, { __array: [] }],
              checklist: [{ __array: [{ text: 'water', done: true }] }],
            },
          },
        }),
      ),
    );
  });
});

describe('other users and signed-out clients', () => {
  test('another user cannot read the owner\'s tree', async () => {
    const db = other();
    await assertFails(getDoc(doc(db, `users/${OWNER}/lists/plants`)));
    await assertFails(getDoc(doc(db, `users/${OWNER}/lists/plants/items/fern`)));
    await assertFails(getDocs(collection(db, `users/${OWNER}/lists`)));
    await assertFails(getDocs(collection(db, `users/${OWNER}/lists/plants/items`)));
  });

  test('another user cannot write the owner\'s tree', async () => {
    const db = other();
    await assertFails(setDoc(doc(db, `users/${OWNER}/lists/books`), list('books')));
    await assertFails(setDoc(doc(db, `users/${OWNER}/lists/plants`), list('plants')));
    await assertFails(deleteDoc(doc(db, `users/${OWNER}/lists/plants`)));
    await assertFails(
      setDoc(doc(db, `users/${OWNER}/lists/plants/items/ivy`), item('ivy', 'plants')),
    );
    await assertFails(deleteDoc(doc(db, `users/${OWNER}/lists/plants/items/fern`)));
  });

  test('a signed-out client can neither read nor write', async () => {
    const db = signedOut();
    await assertFails(getDoc(doc(db, `users/${OWNER}/lists/plants`)));
    await assertFails(getDocs(collection(db, `users/${OWNER}/lists`)));
    await assertFails(getDoc(doc(db, `users/${OWNER}/lists/plants/items/fern`)));
    await assertFails(setDoc(doc(db, `users/${OWNER}/lists/books`), list('books')));
    await assertFails(
      setDoc(doc(db, `users/${OWNER}/lists/plants/items/ivy`), item('ivy', 'plants')),
    );
    await assertFails(deleteDoc(doc(db, `users/${OWNER}/lists/plants`)));
  });

  test('nothing outside users/{uid}/lists is open, not even to the owner', async () => {
    const db = owner();
    await assertFails(getDoc(doc(db, `users/${OWNER}`)));
    await assertFails(setDoc(doc(db, `users/${OWNER}`), { name: 'x' }));
    await assertFails(setDoc(doc(db, `users/${OWNER}/settings/app`), { theme: 'dark' }));
    await assertFails(setDoc(doc(db, 'shared/x'), { a: 1 }));
    await assertFails(getDocs(collection(db, 'users')));
  });
});

describe('list shape', () => {
  const ref = () => doc(owner(), `users/${OWNER}/lists/books`);

  test('the document id must equal the `id` field', async () => {
    await assertFails(setDoc(ref(), list('plants')));
  });

  for (const key of ['id', 'icon', 'color', 'fields', 'view', 'updatedAt']) {
    test(`the required key "${key}" must be present`, async () => {
      await assertFails(setDoc(ref(), without(list('books'), key)));
    });
  }

  test('wrong types are refused', async () => {
    await assertFails(setDoc(ref(), list('books', { fields: { name: 'text' } })));
    await assertFails(setDoc(ref(), list('books', { view: 'checklist' })));
    await assertFails(setDoc(ref(), list('books', { icon: 7 })));
    await assertFails(setDoc(ref(), list('books', { behaviors: 'none' })));
    await assertFails(setDoc(ref(), list('books', { schemaRevision: '2' })));
    await assertFails(setDoc(ref(), list('books', { updatedAt: new Date() })));
  });

  test('size limits: ids, keys, fields and behaviors', async () => {
    const longId = 'x'.repeat(129);
    await assertFails(
      setDoc(doc(owner(), `users/${OWNER}/lists/${longId}`), list(longId)),
    );
    const extra = Object.fromEntries(Array.from({ length: 30 }, (_, i) => [`k${i}`, i]));
    await assertFails(setDoc(ref(), list('books', extra)));
    const fields = Array.from({ length: 101 }, (_, i) => ({ key: `f${i}`, type: 'text' }));
    await assertFails(setDoc(ref(), list('books', { fields })));
    await assertSucceeds(setDoc(ref(), list('books', { fields: fields.slice(0, 100) })));
    const behaviors = Array.from({ length: 51 }, () => ({ kind: 'clearCompleted' }));
    await assertFails(setDoc(ref(), list('books', { behaviors })));
  });

  test('an update is checked like a create', async () => {
    await assertFails(
      setDoc(doc(owner(), `users/${OWNER}/lists/plants`), without(list('plants'), 'view')),
    );
  });
});

describe('item shape', () => {
  const ref = () => doc(owner(), `users/${OWNER}/lists/plants/items/ivy`);

  test('the document id must equal the `id` field', async () => {
    await assertFails(setDoc(ref(), item('fern', 'plants')));
  });

  test('`listId` must equal the parent list', async () => {
    await assertFails(setDoc(ref(), item('ivy', 'books')));
  });

  for (const key of ['id', 'listId', 'values', 'createdAt', 'updatedAt']) {
    test(`the required key "${key}" must be present`, async () => {
      await assertFails(setDoc(ref(), without(item('ivy', 'plants'), key)));
    });
  }

  test('wrong types are refused', async () => {
    await assertFails(setDoc(ref(), item('ivy', 'plants', { values: ['fern'] })));
    await assertFails(setDoc(ref(), item('ivy', 'plants', { createdAt: 5 })));
    await assertFails(setDoc(ref(), item('ivy', 'plants', { _rev: '2' })));
  });

  test('size limits: keys and values', async () => {
    const extra = Object.fromEntries(Array.from({ length: 7 }, (_, i) => [`k${i}`, i]));
    await assertFails(setDoc(ref(), item('ivy', 'plants', extra)));
    const values = Object.fromEntries(Array.from({ length: 201 }, (_, i) => [`v${i}`, i]));
    await assertFails(setDoc(ref(), item('ivy', 'plants', { values })));
    delete values.v200;
    await assertSucceeds(setDoc(ref(), item('ivy', 'plants', { values })));
  });
});
