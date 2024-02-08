// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

open class ZuperLogsiOS {

    /// version string of framework
    public static let version = "1.9.6"  // UPDATE ON RELEASE!
    /// build number of framework
    public static let build = 1960 // version 1.6.2 -> 1620, UPDATE ON RELEASE!

    public enum Level: Int {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        
        var value: String {
            switch self {
            case .verbose:
                return "verbose"
            case .debug:
                return "debug"
            case .info:
                return "info"
            case .warning:
                return "warn"
            case .error:
                return "error"
            }
        }
    }

    // a set of active destinations
    public private(set) static var destinations = Set<BaseDestination>()

    // MARK: Destination Handling

    /// returns boolean about success
    @discardableResult
    open class func addDestination(_ destination: BaseDestination) -> Bool {
        if destinations.contains(destination) {
            return false
        }
        destinations.insert(destination)
        return true
    }

    /// returns boolean about success
    @discardableResult
    open class func removeDestination(_ destination: BaseDestination) -> Bool {
        if destinations.contains(destination) == false {
            return false
        }
        destinations.remove(destination)
        return true
    }

    /// if you need to start fresh
    open class func removeAllDestinations() {
        destinations.removeAll()
    }

    /// returns the amount of destinations
    open class func countDestinations() -> Int {
        return destinations.count
    }

    /// returns the current thread name
    open class func threadName() -> String {

        #if os(Linux)
            // on 9/30/2016 not yet implemented in server-side Swift:
            // > import Foundation
            // > Thread.isMainThread
            return ""
        #else
            if Thread.isMainThread {
                return ""
            } else {
                let name = __dispatch_queue_get_label(nil)
                return String(cString: name, encoding: .utf8) ?? Thread.current.description
            }
        #endif
    }

    // MARK: Levels

    /// log something generally unimportant (lowest priority)
    open class func verbose(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        custom(level: .verbose, message: message(), file: file, function: function, line: line, payload: payload)
        #else
        custom(level: .verbose, message: message, file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// log something which help during debugging (low priority)
    open class func debug(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        custom(level: .debug, message: message(), file: file, function: function, line: line, payload: payload)
        #else
        custom(level: .debug, message: message, file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// log something which you are really interested but which is not an issue or error (normal priority)
    open class func info(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        custom(level: .info, message: message(), file: file, function: function, line: line, payload: payload)
        #else
        custom(level: .info, message: message, file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// log something which may cause big trouble soon (high priority)
    open class func warning(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        custom(level: .warning, message: message(), file: file, function: function, line: line, payload: payload)
        #else
        custom(level: .warning, message: message, file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// log something which will keep you awake at night (highest priority)
    open class func error(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        custom(level: .error, message: message(), file: file, function: function, line: line, payload: payload)
        #else
        custom(level: .error, message: message, file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// custom logging to manually adjust values, should just be used by other frameworks
    open class func custom(level: ZuperLogsiOS.Level, message: @autoclosure () -> Any,
                           file: String = #file, function: String = #function, line: Int = #line, payload: [String: Any]? = nil) {
        #if swift(>=5)
        dispatch_send(level: level, message: message(), thread: threadName(),
                      file: file, function: function, line: line, payload: payload)
        #else
        dispatch_send(level: level, message: message, thread: threadName(),
                      file: file, function: function, line: line, payload: payload)
        #endif
    }

    /// internal helper which dispatches send to dedicated queue if minLevel is ok
    class func dispatch_send(level: ZuperLogsiOS.Level, message: @autoclosure () -> Any,
                             thread: String, file: String, function: String, line: Int, payload: [String: Any]?) {
        var resolvedMessage: String?
        for dest in destinations {

            guard let queue = dest.queue else {
                continue
            }

            resolvedMessage = resolvedMessage == nil && dest.hasMessageFilters() ? "\(message())" : resolvedMessage
            if dest.shouldLevelBeLogged(level, path: file, function: function, message: resolvedMessage) {
                // try to convert msg object to String and put it on queue
                let msgStr = resolvedMessage == nil ? "\(message())" : resolvedMessage!
                let f = stripParams(function: function)

                if dest.asynchronously {
                    queue.async {
                        _ = dest.send(level, msg: msgStr, thread: thread, file: file, function: f, line: line, payload: payload)
                    }
                } else {
                    queue.sync {
                        _ = dest.send(level, msg: msgStr, thread: thread, file: file, function: f, line: line, payload: payload)
                    }
                }
            }
        }
    }

    /// flush all destinations to make sure all logging messages have been written out
    /// returns after all messages flushed or timeout seconds
    /// returns: true if all messages flushed, false if timeout or error occurred
    public class func flush(secondTimeout: Int64) -> Bool {
        let grp = DispatchGroup()
        for dest in destinations {
            guard let queue = dest.queue else {
                continue
            }
            grp.enter()
            if dest.asynchronously {
                queue.async {
                    dest.flush()
                    grp.leave()
                }
            } else {
                queue.sync {
                    dest.flush()
                    grp.leave()
                }
            }
        }
        return grp.wait(timeout: .now() + .seconds(Int(secondTimeout))) == .success
    }

    /// removes the parameters from a function because it looks weird with a single param
    class func stripParams(function: String) -> String {
        var f = function
        if let indexOfBrace = f.find("(") {
            #if swift(>=4.0)
            f = String(f[..<indexOfBrace])
            #else
            f = f.substring(to: indexOfBrace)
            #endif
        }
        f += "()"
        return f
    }
}
