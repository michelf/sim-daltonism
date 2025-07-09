// Backports the Swift 6 type Mutex<Value> to Swift 5
// from https://github.com/swhitty/swift-mutex/blob/main/Sources/MutexSwift5.swift

public struct Mutex<Value>: @unchecked Sendable {
	let storage: Storage<Value>

	public init(_ initialValue: Value) {
		self.storage = Storage(initialValue)
	}

	public borrowing func withLock<Result>(
		_ body: (inout Value) throws -> Result
	) rethrows -> Result {
		storage.lock()
		defer { storage.unlock() }
		return try body(&storage.value)
	}

	public borrowing func withLockIfAvailable<Result>(
		_ body: (inout Value) throws -> Result
	) rethrows -> Result? {
		guard storage.tryLock() else { return nil }
		defer { storage.unlock() }
		return try body(&storage.value)
	}
}



import struct os.os_unfair_lock_t
import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock
import func os.os_unfair_lock_trylock

final class Storage<Value> {
	private let _lock: os_unfair_lock_t
	var value: Value

	init(_ initialValue: consuming Value) {
		self._lock = .allocate(capacity: 1)
		self._lock.initialize(to: os_unfair_lock())
		self.value = initialValue
	}

	func lock() {
		os_unfair_lock_lock(_lock)
	}

	func unlock() {
		os_unfair_lock_unlock(_lock)
	}

	func tryLock() -> Bool {
		os_unfair_lock_trylock(_lock)
	}

	deinit {
		self._lock.deinitialize(count: 1)
		self._lock.deallocate()
	}
}
