import Dispatch

/// DispatchQueue-based mutual exclusion protecting a mutable value. Value can be accessed by locking
/// synchronously or enqueuing tasks to run asynchrounsly on the queue.
public struct DispatchQueueMutex<Value: ~Copyable>: ~Copyable {
	private let storage: Storage<Value>
	let queue: DispatchQueue

	public init(_ initialValue: consuming sending Value, label: String, qos: DispatchQoS = .unspecified, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit, target: DispatchQueue? = nil) {
		self.storage = Storage(initialValue)
		self.queue = DispatchQueue(label: label, qos: qos, attributes: [], autoreleaseFrequency: autoreleaseFrequency, target: target)
	}

	public borrowing func withLock<Result, E: Error>(
	_ body: (inout sending Value) throws(E) -> sending Result
	) throws(E) -> sending Result {
		let result = queue.sync { [storage] in
			Swift.Result { () throws(E) -> Result in
				try body(&storage.value)
			}
		}
		return try result.get()
	}

	public borrowing func enqueue(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (inout sending Value) -> ()) {
		queue.async(group: group, qos: qos, flags: flags) { [storage] in
			body(&storage.value)
		}
	}

	public borrowing func enqueueAfter(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (inout sending Value) -> ()) {
		queue.asyncAfter(deadline: deadline, qos: qos, flags: flags) { [storage] in
			body(&storage.value)
		}
	}

	@available(macOS 10.15, *)
	public borrowing func queued<Result, E: Error>(
		group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
		_ body: sending @escaping (inout sending Value) throws(E) -> sending Result
	) async throws(E) -> sending Result {
		return try await withCheckedContinuation { continuation in
			enqueue(group: group, qos: qos, flags: flags) { state in
				let result = Swift.Result { () throws(E) -> Result in
					try body(&state)
				}
				continuation.resume(returning: result)
			}
		}.get()
	}

}

extension DispatchQueueMutex: @unchecked Sendable where Value: ~Copyable { }

/// DispatchQueue-based multiple-reader single-writer mutual exclusion protecting a mutable value.
/// Value can be accessed by locking synchronously or enqueuing tasks to run asynchrounsly on the queue.
/// Reads can run concurrently and writes are run serially with other write or read operations.
public struct DispatchQueueRWMutex<Value: ~Copyable>: ~Copyable {
	private let storage: Storage<Value>
	let queue: DispatchQueue

	public init(_ initialValue: consuming sending Value, label: String, qos: DispatchQoS = .unspecified, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit, target: DispatchQueue? = nil) {
		self.storage = Storage(initialValue)
		// note: using .concurrent attribute because we want concurrent reads
		// and using .barrier flag for writes to ensure exclusivity
		self.queue = DispatchQueue(label: label, qos: qos, attributes: [.concurrent], autoreleaseFrequency: autoreleaseFrequency, target: target)
	}

	public borrowing func withReadLock<Result, E: Error>(
		_ body: (borrowing Value) throws(E) -> sending Result
	) throws(E) -> sending Result {
		let result = queue.sync { [storage] in
			Swift.Result { () throws(E) -> Result in
				try body(storage.value)
			}
		}
		return try result.get()
	}

	public borrowing func withWriteLock<Result, E: Error>(
		_ body: (inout sending Value) throws(E) -> sending Result
	) throws(E) -> sending Result {
		let result = queue.sync(flags: [.barrier]) { [storage] in
			Swift.Result { () throws(E) -> Result in
				try body(&storage.value)
			}
		}
		return try result.get()
	}

	public borrowing func enqueueRead(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (borrowing Value) -> ()) {
		queue.async(group: group, qos: qos, flags: flags) { [storage] in
			body(storage.value)
		}
	}
	public borrowing func enqueueWrite(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (inout sending Value) -> ()) {
		queue.async(group: group, qos: qos, flags: [flags, .barrier]) { [storage] in
			body(&storage.value)
		}
	}

	public borrowing func enqueueReadAfter(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (borrowing Value) -> ()) {
		queue.asyncAfter(deadline: deadline, qos: qos, flags: flags) { [storage] in
			body(storage.value)
		}
	}
	public borrowing func enqueueWriteAfter(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], _ body: sending @escaping (inout sending Value) -> ()) {
		queue.asyncAfter(deadline: deadline, qos: qos, flags: [flags, .barrier]) { [storage] in
			body(&storage.value)
		}
	}

	@available(macOS 10.15, *)
	public borrowing func queuedRead<Result, E: Error>(
		group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
		_ body: sending @escaping (borrowing Value) throws(E) -> sending Result
	) async throws(E) -> sending Result {
		return try await withCheckedContinuation { continuation in
			enqueueRead(group: group, qos: qos, flags: flags) { state in
				let result = Swift.Result { () throws(E) -> Result in
					try body(state)
				}
				continuation.resume(returning: result)
			}
		}.get()
	}
	@available(macOS 10.15, *)
	public borrowing func queuedWrite<Result, E: Error>(
		group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
		_ body: sending @escaping (inout sending Value) throws(E) -> sending Result
	) async throws(E) -> sending Result {
		return try await withCheckedContinuation { continuation in
			enqueueWrite(group: group, qos: qos, flags: flags) { state in
				let result = Swift.Result { () throws(E) -> Result in
					try body(&state)
				}
				continuation.resume(returning: result)
			}
		}.get()
	}

}

extension DispatchQueueRWMutex: @unchecked Sendable where Value: ~Copyable { }

private final class Storage<Value: ~Copyable> {
	var value: Value

	init(_ value: consuming sending Value) {
		self.value = value
	}
}
