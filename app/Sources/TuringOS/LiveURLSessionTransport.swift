// LiveURLSessionTransport.swift — A1_31: live URLSession implementation of ModelTransport.
//
// Constitutional anchors:
//   - docs/01_KERNEL_CONTRACTS.md I9 — credentials never logged: headers
//     (including Authorization) pass through to the wire VERBATIM and are
//     never printed, recorded, or surfaced in any error message.
//   - WHITEPAPER.md §13.7 — Model Gateway = bottom-whitebox pipe; this file
//     is the live wire only. ZERO gating/routing decisions live here.
//
// LIVE DOMAIN — zero-network test discipline (A1_22): this type is NEVER
// constructed in tests. Tests inject MockTransport; the ModelTransport
// protocol seam is the only coupling point. If a test ever needs this type,
// that test is wrong, not this comment.

import Foundation

// MARK: - LiveURLSessionTransport

/// URLSession-backed ModelTransport for live provider calls.
///
/// Behaviour (all of it, nothing else):
///   - POST `body` to `url` with `headers` applied verbatim.
///   - Return the raw response body on HTTP 2xx.
///   - Throw GatewayError.providerError("HTTP <code>: <first 200 chars of body>")
///     on any non-2xx status.
///   - 120 s request timeout via URLSessionConfiguration.
///
/// I9: the Authorization header value flows ONLY into the URLRequest —
/// no logging, no echo into thrown errors (error text carries the RESPONSE
/// body prefix, never request headers).
public struct LiveURLSessionTransport: ModelTransport {

    /// Request timeout in seconds (provider thinking models can be slow).
    public static let timeoutSeconds: TimeInterval = 120

    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest  = Self.timeoutSeconds
        configuration.timeoutIntervalForResource = Self.timeoutSeconds
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - ModelTransport

    public func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Headers applied verbatim (I9: never logged, never inspected).
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.providerError("non-HTTP response from \(url.host ?? "unknown host")")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Response-body prefix only — request headers NEVER appear here (I9).
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw GatewayError.providerError("HTTP \(http.statusCode): \(String(bodyText.prefix(200)))")
        }
        return data
    }
}
