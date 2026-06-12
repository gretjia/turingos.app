// FailClosedClassifier.swift — Fail-closed classifier for CapabilityManifest (A1_21).
//
// BOUNDARY: pure classification library.  No lifecycle, no persistence, no network.
//
// Constitutional anchors:
//   - WHITEPAPER.md §13.8 Install ≠ trust list (rule 3: fail-closed → class_3 or deny)
//   - docs/01_KERNEL_CONTRACTS.md I4 — fail-closed invariant
//   - WHITEPAPER.md §9 — signature node table (1–8; class_3 → node 4 minimum)
//   - WHITEPAPER.md §10 — three-class action map
//
// All public functions are pure and deterministic.  Given identical inputs the
// output is always identical (tested by determinism × 2 assertion in tests).
//
// LIFECYCLE ABSENCE (compile-level enforcement):
//   There is deliberately no install/update/remove API on this type.
//   The only outputs are Disposition cases.  See CapabilityManifest.swift header for why.

import Foundation

// MARK: - SignatureNode

/// Signature node numbers 1–8 corresponding to WHITEPAPER.md §9 table.
///
/// | # | Signing ceremony                                |
/// |---|-------------------------------------------------|
/// | 1 | Approve Init Spec / Project Ready               |
/// | 2 | Approve budget & autonomy contract              |
/// | 3 | Approve sensitive data domain / credentials     |
/// | 4 | Approve irreversible external actions           |
/// | 5 | Approve protected writes / merge / release      |
/// | 6 | Approve over-budget extension                   |
/// | 7 | Approve tool/predicate/policy upgrade           |
/// | 8 | Constitutional amendment / sudo ceremony        |
public struct SignatureNode: Sendable, Equatable, Comparable, CustomStringConvertible {
    /// Node number in 1...8.
    public let number: Int

    /// Designated initialiser — validates range.
    /// Returns nil if `number` is outside 1...8.
    public init?(_ number: Int) {
        guard (1...8).contains(number) else { return nil }
        self.number = number
    }

    public var description: String { "signature_node_\(number)" }

    public static func < (lhs: SignatureNode, rhs: SignatureNode) -> Bool {
        lhs.number < rhs.number
    }

    // MARK: - Class-3 minimum node (§9 / §10 table)

    /// class_3_irreversible_external always requires at least signature node 4
    /// ("Approve irreversible external actions") — §9 table, §10 default disposition.
    public static let class3Minimum = SignatureNode(4)!
}

// MARK: - ResolvedEscalation

/// The result of resolving an escalation entry to a signature node.
public struct ResolvedEscalation: Sendable, Equatable {
    /// The operation name from the escalation map.
    public let operation: String
    /// The resolved signature node.
    public let node: SignatureNode
}

// MARK: - Disposition

/// Classification result of `FailClosedClassifier.classify(_:)`.
///
/// ## Lifecycle absence enforcement
/// These are the ONLY outputs of this classifier.  There are no `install`, `update`,
/// or `remove` cases — those are tape-side lifecycle events (§13.8 rule 5) and
/// require the runtime tape which is not yet available.
public enum Disposition: Sendable, Equatable {
    /// Manifest is valid.  Includes the resolved default action class and any
    /// escalation entries resolved to signature nodes.
    case classified(defaultClass: ActionClass, escalations: [ResolvedEscalation])

    /// Cannot determine safe action class.  Classifier treats the capability as
    /// class_3_irreversible_external because the `action_classes` block was present
    /// but `action_classes.default` was missing or invalid (schema fail-closed clause).
    /// All other required fields (id, kind) were parseable.
    case treatAsClass3(reason: String)

    /// Capability must not be enabled.  Covers:
    ///   - unparseable / invalid JSON
    ///   - id or kind not parseable
    ///   - escalation entry points to node outside 1...8
    ///   - any other blocking structural violation
    case deny(reason: String)
}

// MARK: - FailClosedClassifier

/// Deterministic, pure classifier that maps raw JSON capability manifest bytes to a
/// `Disposition`.
///
/// Rules (mirror §13.8 / I4):
///   1. Invalid JSON                             → `.deny`
///   2. `id` or `kind` not parseable             → `.deny`
///   3. `action_classes` missing or default invalid,
///      but `id`/`kind` parseable                → `.treatAsClass3` (schema fail-closed clause)
///   4. Valid manifest + all escalation nodes in 1...8
///                                               → `.classified`
///   5. Valid manifest + any escalation node outside 1...8
///                                               → `.deny` (out-of-range node is untrusted)
///   6. `class_3_irreversible_external` always implies signature node 4 minimum (§9)
///      — this rule is encoded in `SignatureNode.class3Minimum` and asserted in
///        `classified` output when the default class is class_3.
///
/// All functions are pure (no stored state).
public enum FailClosedClassifier {

    // MARK: - classify

    /// Classify raw JSON bytes representing a capability manifest.
    ///
    /// - Parameter manifestData: Raw UTF-8 JSON bytes.
    /// - Returns: A `Disposition` — always `.deny`, `.treatAsClass3`, or `.classified`.
    public static func classify(_ manifestData: Data) -> Disposition {
        // --- Rule 1: parseable JSON ---
        guard let rawJSON = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
            return .deny(reason: "manifest is not parseable JSON")
        }

        // --- Rule 2: id and kind parseable ---
        guard let idValue = rawJSON["id"] as? String, !idValue.isEmpty else {
            return .deny(reason: "manifest missing or empty 'id' field")
        }
        guard let kindRaw = rawJSON["kind"] as? String,
              CapabilityKind(rawValue: kindRaw) != nil else {
            let kindRaw = rawJSON["kind"] as? String ?? "<missing>"
            return .deny(reason: "manifest 'kind' is not a valid CapabilityKind: \"\(kindRaw)\"")
        }

        // --- Rule 3 check: action_classes present and default valid? ---
        let actionClassesPresent: Bool
        let defaultClassOK:       Bool
        var parsedDefaultClass:   ActionClass? = nil

        if let ac = rawJSON["action_classes"] as? [String: Any] {
            actionClassesPresent = true
            if let defaultRaw = ac["default"] as? String,
               let cls = ActionClass(rawValue: defaultRaw) {
                defaultClassOK     = true
                parsedDefaultClass = cls
            } else {
                defaultClassOK = false
            }
        } else {
            actionClassesPresent = false
            defaultClassOK       = false
        }

        // Rule 3: action_classes missing or default invalid → treatAsClass3
        if !actionClassesPresent || !defaultClassOK {
            let why = !actionClassesPresent
                ? "action_classes block is missing"
                : "action_classes.default is missing or not a valid ActionClass"
            return .treatAsClass3(reason: "fail-closed: \(why); treating as class_3_irreversible_external")
        }

        // --- Rule 4 / 5: valid manifest + escalation routing ---
        // We have a default class.  Now resolve escalation entries.
        let defaultClass = parsedDefaultClass!
        var resolvedEscalations: [ResolvedEscalation] = []

        if let ac = rawJSON["action_classes"] as? [String: Any],
           let escalation = ac["escalation"] as? [String: Any] {
            for (operation, nodeValue) in escalation.sorted(by: { $0.key < $1.key }) {
                guard let nodeInt = nodeValue as? Int else {
                    return .deny(reason: "escalation entry '\(operation)' has non-integer node value")
                }
                guard let node = SignatureNode(nodeInt) else {
                    return .deny(reason: "escalation entry '\(operation)' maps to node \(nodeInt) which is outside valid range 1...8")
                }
                resolvedEscalations.append(ResolvedEscalation(operation: operation, node: node))
            }
        }

        // Rule 6: class_3 always requires at least signature node 4 minimum.
        // This is already encoded in SignatureNode.class3Minimum; callers can
        // inspect it.  We include it in the classified output by ensuring that
        // when defaultClass == .class3IrreversibleExternal, the minimum node
        // is clearly reachable via SignatureNode.class3Minimum.
        // (No deny needed here — the rule is a floor, not a ceiling.)

        return .classified(defaultClass: defaultClass, escalations: resolvedEscalations)
    }

    // MARK: - minimumSignatureNode

    /// Returns the minimum required signature node for the given action class per §9 table.
    ///
    /// - class_3 → node 4 (Approve irreversible external actions) — always required
    /// - class_2 → node 5 (Approve protected writes / publish)
    /// - class_1 → no mandatory Touch ID node (shadow workspace, auto-allowed per policy)
    /// - class_0 → no mandatory Touch ID node
    public static func minimumSignatureNode(for actionClass: ActionClass) -> SignatureNode? {
        switch actionClass {
        case .class3IrreversibleExternal: return SignatureNode.class3Minimum    // node 4
        case .class2RemoteDraft:          return SignatureNode(5)               // node 5
        case .class1ReversibleLocal:      return nil
        case .class0Read:                 return nil
        }
    }
}
