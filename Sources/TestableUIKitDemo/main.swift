import Foundation
import TestableUIKit
import Dispatch

// CLI は SwiftUI 環境を持たないため、Registry を直接生成して Server へ注入する
let registry = TestableRegistry()
let button = CLIDemoLoginButton()
do {
  let server = try TestableServer(port: 8888, registry: registry)

  Task {
    await registry.register(button)
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
