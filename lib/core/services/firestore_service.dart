import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePageResult {
  const FirestorePageResult({
    required this.docs,
    required this.hasMore,
    this.lastDocument,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hasMore;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, String? universiteId})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _universiteId = universiteId ?? _defaultUniversiteId;

  final FirebaseFirestore _firestore;
  final String _universiteId;

  static const String _defaultUniversiteId = 'usak';

  static String _activeUniversiteId = _defaultUniversiteId;
  static String get activeUniversiteId => _activeUniversiteId;
  static set activeUniversiteId(String value) {
    _activeUniversiteId = value;
  }

  DocumentReference get universiteRef =>
      _firestore.collection('universiteler').doc(_universiteId);

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      universiteRef.collection(path);

  Future<String> create(String collectionPath, Map<String, dynamic> data) async {
    final docRef = await collection(collectionPath).add(data);
    return docRef.id;
  }

  Future<void> set(
    String collectionPath,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await collection(collectionPath).doc(docId).set(data, SetOptions(merge: merge));
  }

  Future<void> update(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await collection(collectionPath).doc(docId).update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> get(
    String collectionPath,
    String docId,
  ) async {
    return collection(collectionPath).doc(docId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getAll(
    String collectionPath, {
    Query<Map<String, dynamic>> Function(CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  }) async {
    final ref = collection(collectionPath);
    if (queryBuilder != null) {
      return queryBuilder(ref).get() as Future<QuerySnapshot<Map<String, dynamic>>>;
    }
    return ref.get();
  }

  Future<FirestorePageResult> getPage(
    String collectionPath, {
    Query<Map<String, dynamic>> Function(CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final ref = collection(collectionPath);
    Query<Map<String, dynamic>> query =
        queryBuilder != null ? queryBuilder(ref) : ref;

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limit).get();
    final docs = snapshot.docs;
    return FirestorePageResult(
      docs: docs,
      hasMore: docs.length == limit,
      lastDocument: docs.isEmpty ? startAfterDocument : docs.last,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> stream(
    String collectionPath, {
    Query<Map<String, dynamic>> Function(CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  }) {
    final ref = collection(collectionPath);
    if (queryBuilder != null) {
      return queryBuilder(ref).snapshots()
          as Stream<QuerySnapshot<Map<String, dynamic>>>;
    }
    return ref.snapshots();
  }

  Future<void> delete(String collectionPath, String docId) async {
    await collection(collectionPath).doc(docId).delete();
  }

  Future<DocumentReference<Map<String, dynamic>>> add(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    return collection(collectionPath).add(data);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> where(
    String collectionPath, {
    required String field,
    required dynamic isEqualTo,
  }) async {
    return collection(collectionPath)
        .where(field, isEqualTo: isEqualTo)
        .get();
  }

  WriteBatch batch() => _firestore.batch();

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');
}
