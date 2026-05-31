import Foundation
import TestableUIKit
import Dispatch

let button = CLIDemoLoginButton()
do {
  let server = try TestableServer(port: 8888)
  
  Task {
    await TestableRegistry.shared.register(button)
  }
  
  server.start()

  print("✅ TestableServer running on http://localhost:8888")
  print("   GET  http://localhost:8888/ping")
  print("   POST http://localhost:8888/perform")
  print("")
  print("Run: python3 run_test.py")
  print("Press Ctrl+C to quit")
  print("")

  dispatchMain()
} catch {
  print("❌ Fatal error: \(error)")
  exit(1)
}
