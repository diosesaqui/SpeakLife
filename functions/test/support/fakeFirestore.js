/**
 * A small in-memory Firestore, enough for the For You service: documents,
 * subcollections, merge writes, and where('<=') / orderBy / limit queries.
 * Paths are stored flat, "forYou/u1/weeks/2026-10-25".
 */

function createFakeFirestore() {
  const docs = new Map();
  const writes = [];

  function snapshot(path) {
    const data = docs.get(path);
    const id = path.split('/').pop();
    return { id, exists: data !== undefined, data: () => (data === undefined ? undefined : structuredClone(data)), ref: docRef(path) };
  }

  function docRef(path) {
    return {
      id: path.split('/').pop(),
      path,
      async get() { return snapshot(path); },
      async set(data, options = {}) {
        writes.push({ path, data: structuredClone(data), merge: !!options.merge });
        const base = options.merge ? (docs.get(path) || {}) : {};
        docs.set(path, { ...base, ...structuredClone(data) });
      },
      collection(name) { return collectionRef(`${path}/${name}`); },
    };
  }

  function query(prefix, filters, order, max) {
    return {
      where(field, op, value) {
        if (op !== '<=') throw new Error(`fake firestore: unsupported op ${op}`);
        return query(prefix, [...filters, { field, value }], order, max);
      },
      orderBy(field, dir = 'asc') { return query(prefix, filters, { field, dir }, max); },
      limit(n) { return query(prefix, filters, order, n); },
      async get() {
        const depth = prefix.split('/').length + 1;
        let rows = [...docs.keys()]
          .filter((p) => p.startsWith(`${prefix}/`) && p.split('/').length === depth)
          .map((p) => ({ path: p, data: docs.get(p) }))
          .filter((r) => filters.every((f) => r.data[f.field] !== undefined && r.data[f.field] !== null && r.data[f.field] <= f.value));
        if (order) {
          rows.sort((a, b) => {
            const x = a.data[order.field];
            const y = b.data[order.field];
            return order.dir === 'desc' ? (y > x ? 1 : y < x ? -1 : 0) : (x > y ? 1 : x < y ? -1 : 0);
          });
        }
        if (max !== undefined) rows = rows.slice(0, max);
        return { docs: rows.map((r) => snapshot(r.path)), empty: rows.length === 0 };
      },
    };
  }

  function collectionRef(path) {
    return {
      doc(id) { return docRef(`${path}/${id}`); },
      ...query(path, [], null, undefined),
    };
  }

  return {
    collection: (name) => collectionRef(name),
    docs,
    writes,
    read: (path) => docs.get(path),
    put: (path, data) => docs.set(path, structuredClone(data)),
  };
}

module.exports = { createFakeFirestore };
