struct WeakReference<T> {
  private let getReference: () -> T?

  init(_ object: T) {
    let reference = object as AnyObject

    getReference = { [weak reference] in
      reference as? T
    }
  }

  func get() -> T? { getReference() }
}
