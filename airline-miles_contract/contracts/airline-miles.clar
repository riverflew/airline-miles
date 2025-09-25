
;; title: airline-miles
;; version: 1.0.0
;; summary: A verification smart contract for frequent flyer points ownership and loyalty program validation
;; description: This contract manages airline loyalty programs, tracks frequent flyer points,
;;              and provides verification mechanisms for points ownership and transfers.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_AIRLINE_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_REGISTERED (err u104))
(define-constant ERR_NOT_REGISTERED (err u105))
(define-constant ERR_INVALID_TIER (err u106))

;; Loyalty tiers
(define-constant TIER_BRONZE u1)
(define-constant TIER_SILVER u2)
(define-constant TIER_GOLD u3)
(define-constant TIER_PLATINUM u4)

;; data vars
(define-data-var contract-paused bool false)

;; data maps

;; Store airline information
(define-map airlines
    { airline-id: uint }
    {
        name: (string-ascii 50),
        is-active: bool,
        points-multiplier: uint
    }
)

;; Store user loyalty accounts
(define-map loyalty-accounts
    { user: principal, airline-id: uint }
    {
        points-balance: uint,
        tier: uint,
        lifetime-points: uint,
        registration-block: uint
    }
)

;; Store points transactions for verification
(define-map points-transactions
    { tx-id: uint }
    {
        from: principal,
        to: principal,
        airline-id: uint,
        amount: uint,
        transaction-type: (string-ascii 20),
        block-height: uint
    }
)

;; Store next transaction ID
(define-data-var next-tx-id uint u1)

;; Store next airline ID
(define-data-var next-airline-id uint u1)

;; public functions

;; Register a new airline (only contract owner)
(define-public (register-airline (name (string-ascii 50)) (points-multiplier uint))
    (let ((airline-id (var-get next-airline-id)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (> points-multiplier u0) ERR_INVALID_AMOUNT)

        (map-set airlines
            { airline-id: airline-id }
            {
                name: name,
                is-active: true,
                points-multiplier: points-multiplier
            }
        )
        (var-set next-airline-id (+ airline-id u1))
        (ok airline-id)
    )
)

;; Register user for a loyalty program
(define-public (register-loyalty-account (airline-id uint))
    (let ((account-key { user: tx-sender, airline-id: airline-id }))
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? airlines { airline-id: airline-id })) ERR_AIRLINE_NOT_FOUND)
        (asserts! (is-none (map-get? loyalty-accounts account-key)) ERR_ALREADY_REGISTERED)

        (map-set loyalty-accounts
            account-key
            {
                points-balance: u0,
                tier: TIER_BRONZE,
                lifetime-points: u0,
                registration-block: block-height
            }
        )
        (ok true)
    )
)

;; Award points to a user (airline or contract owner only)
(define-public (award-points (user principal) (airline-id uint) (base-points uint))
    (let (
        (airline-data (unwrap! (map-get? airlines { airline-id: airline-id }) ERR_AIRLINE_NOT_FOUND))
        (account-key { user: user, airline-id: airline-id })
        (account-data (unwrap! (map-get? loyalty-accounts account-key) ERR_NOT_REGISTERED))
        (multiplied-points (* base-points (get points-multiplier airline-data)))
        (new-balance (+ (get points-balance account-data) multiplied-points))
        (new-lifetime-points (+ (get lifetime-points account-data) multiplied-points))
        (new-tier (calculate-tier new-lifetime-points))
        (tx-id (var-get next-tx-id))
    )
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (get is-active airline-data)) ERR_UNAUTHORIZED)
        (asserts! (> base-points u0) ERR_INVALID_AMOUNT)

        ;; Update account
        (map-set loyalty-accounts
            account-key
            {
                points-balance: new-balance,
                tier: new-tier,
                lifetime-points: new-lifetime-points,
                registration-block: (get registration-block account-data)
            }
        )

        ;; Record transaction
        (map-set points-transactions
            { tx-id: tx-id }
            {
                from: tx-sender,
                to: user,
                airline-id: airline-id,
                amount: multiplied-points,
                transaction-type: "AWARD",
                block-height: block-height
            }
        )

        (var-set next-tx-id (+ tx-id u1))
        (ok multiplied-points)
    )
)

;; Redeem points (user only)
(define-public (redeem-points (airline-id uint) (points-to-redeem uint))
    (let (
        (account-key { user: tx-sender, airline-id: airline-id })
        (account-data (unwrap! (map-get? loyalty-accounts account-key) ERR_NOT_REGISTERED))
        (current-balance (get points-balance account-data))
        (tx-id (var-get next-tx-id))
    )
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (>= current-balance points-to-redeem) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> points-to-redeem u0) ERR_INVALID_AMOUNT)

        ;; Update balance
        (map-set loyalty-accounts
            account-key
            (merge account-data { points-balance: (- current-balance points-to-redeem) })
        )

        ;; Record transaction
        (map-set points-transactions
            { tx-id: tx-id }
            {
                from: tx-sender,
                to: tx-sender,
                airline-id: airline-id,
                amount: points-to-redeem,
                transaction-type: "REDEEM",
                block-height: block-height
            }
        )

        (var-set next-tx-id (+ tx-id u1))
        (ok true)
    )
)

;; Transfer points between users
(define-public (transfer-points (recipient principal) (airline-id uint) (points-to-transfer uint))
    (let (
        (sender-key { user: tx-sender, airline-id: airline-id })
        (recipient-key { user: recipient, airline-id: airline-id })
        (sender-data (unwrap! (map-get? loyalty-accounts sender-key) ERR_NOT_REGISTERED))
        (recipient-data (unwrap! (map-get? loyalty-accounts recipient-key) ERR_NOT_REGISTERED))
        (sender-balance (get points-balance sender-data))
        (recipient-balance (get points-balance recipient-data))
        (tx-id (var-get next-tx-id))
    )
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (>= sender-balance points-to-transfer) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> points-to-transfer u0) ERR_INVALID_AMOUNT)
        (asserts! (not (is-eq tx-sender recipient)) ERR_UNAUTHORIZED)

        ;; Update sender balance
        (map-set loyalty-accounts
            sender-key
            (merge sender-data { points-balance: (- sender-balance points-to-transfer) })
        )

        ;; Update recipient balance
        (map-set loyalty-accounts
            recipient-key
            (merge recipient-data { points-balance: (+ recipient-balance points-to-transfer) })
        )

        ;; Record transaction
        (map-set points-transactions
            { tx-id: tx-id }
            {
                from: tx-sender,
                to: recipient,
                airline-id: airline-id,
                amount: points-to-transfer,
                transaction-type: "TRANSFER",
                block-height: block-height
            }
        )

        (var-set next-tx-id (+ tx-id u1))
        (ok true)
    )
)

;; Pause/unpause contract (owner only)
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-paused paused)
        (ok true)
    )
)

;; read only functions

;; Get airline information
(define-read-only (get-airline (airline-id uint))
    (map-get? airlines { airline-id: airline-id })
)

;; Get user's loyalty account
(define-read-only (get-loyalty-account (user principal) (airline-id uint))
    (map-get? loyalty-accounts { user: user, airline-id: airline-id })
)

;; Get points balance for verification
(define-read-only (get-points-balance (user principal) (airline-id uint))
    (match (map-get? loyalty-accounts { user: user, airline-id: airline-id })
        account (ok (get points-balance account))
        ERR_NOT_REGISTERED
    )
)

;; Verify user's tier status
(define-read-only (verify-tier-status (user principal) (airline-id uint))
    (match (map-get? loyalty-accounts { user: user, airline-id: airline-id })
        account (ok (get tier account))
        ERR_NOT_REGISTERED
    )
)

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
    (map-get? points-transactions { tx-id: tx-id })
)

;; Check if user has minimum points for verification
(define-read-only (verify-minimum-balance (user principal) (airline-id uint) (minimum-points uint))
    (match (map-get? loyalty-accounts { user: user, airline-id: airline-id })
        account (ok (>= (get points-balance account) minimum-points))
        ERR_NOT_REGISTERED
    )
)

;; Check if user has specific tier or higher
(define-read-only (verify-tier-or-higher (user principal) (airline-id uint) (required-tier uint))
    (match (map-get? loyalty-accounts { user: user, airline-id: airline-id })
        account (ok (>= (get tier account) required-tier))
        ERR_NOT_REGISTERED
    )
)

;; Get contract status
(define-read-only (get-contract-status)
    {
        paused: (var-get contract-paused),
        next-tx-id: (var-get next-tx-id),
        next-airline-id: (var-get next-airline-id)
    }
)

;; private functions

;; Calculate tier based on lifetime points
(define-private (calculate-tier (lifetime-points uint))
    (if (>= lifetime-points u100000)
        TIER_PLATINUM
        (if (>= lifetime-points u50000)
            TIER_GOLD
            (if (>= lifetime-points u25000)
                TIER_SILVER
                TIER_BRONZE
            )
        )
    )
)
