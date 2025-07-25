(define-non-fungible-token coupon-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-coupon-expired (err u102))
(define-constant err-coupon-already-used (err u103))
(define-constant err-invalid-discount (err u104))
(define-constant err-invalid-expiry (err u105))
(define-constant err-coupon-not-found (err u106))
(define-constant err-unauthorized-merchant (err u107))
(define-constant err-merchant-not-found (err u108))

(define-data-var last-token-id uint u0)

(define-map merchants principal bool)

(define-map coupon-data 
  uint 
  {
    merchant: principal,
    discount-percentage: uint,
    expiry-block: uint,
    max-uses: uint,
    current-uses: uint,
    is-active: bool,
    coupon-type: (string-ascii 20)
  }
)

(define-map coupon-usage 
  {token-id: uint, user: principal} 
  {used: bool, used-block: uint}
)

(define-map merchant-stats 
  principal 
  {
    total-coupons-issued: uint,
    total-coupons-redeemed: uint,
    total-discount-given: uint
  }
)

(define-map user-redemptions 
  principal 
  {
    total-redeemed: uint,
    total-savings: uint
  }
)

(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? coupon-nft token-id))
)

(define-read-only (get-coupon-data (token-id uint))
  (map-get? coupon-data token-id)
)

(define-read-only (is-merchant (address principal))
  (default-to false (map-get? merchants address))
)

(define-read-only (get-merchant-stats (merchant principal))
  (map-get? merchant-stats merchant)
)

(define-read-only (get-user-redemptions (user principal))
  (map-get? user-redemptions user)
)

(define-read-only (is-coupon-valid (token-id uint))
  (match (map-get? coupon-data token-id)
    coupon-info 
    (let 
      (
        (current-block stacks-block-height)
        (is-expired (> current-block (get expiry-block coupon-info)))
        (uses-exhausted (>= (get current-uses coupon-info) (get max-uses coupon-info)))
      )
      {
        valid: (and 
          (get is-active coupon-info)
          (not is-expired)
          (not uses-exhausted)
        ),
        expired: is-expired,
        uses-exhausted: uses-exhausted,
        active: (get is-active coupon-info)
      }
    )
    {valid: false, expired: true, uses-exhausted: true, active: false}
  )
)

(define-read-only (get-coupon-usage (token-id uint) (user principal))
  (map-get? coupon-usage {token-id: token-id, user: user})
)

(define-read-only (calculate-discount (amount uint) (discount-percentage uint))
  (/ (* amount discount-percentage) u100)
)

(define-public (add-merchant (merchant-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set merchants merchant-address true)
    (map-set merchant-stats merchant-address {
      total-coupons-issued: u0,
      total-coupons-redeemed: u0,
      total-discount-given: u0
    })
    (ok true)
  )
)

(define-public (remove-merchant (merchant-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete merchants merchant-address)
    (ok true)
  )
)

(define-public (mint-coupon 
  (recipient principal) 
  (discount-percentage uint) 
  (expiry-blocks uint) 
  (max-uses uint)
  (coupon-type (string-ascii 20))
)
  (let 
    (
      (token-id (+ (var-get last-token-id) u1))
      (expiry-block (+ stacks-block-height expiry-blocks))
      (merchant tx-sender)
    )
    (asserts! (is-merchant merchant) err-unauthorized-merchant)
    (asserts! (and (> discount-percentage u0) (<= discount-percentage u100)) err-invalid-discount)
    (asserts! (> expiry-blocks u0) err-invalid-expiry)
    (asserts! (> max-uses u0) err-invalid-discount)
    
    (try! (nft-mint? coupon-nft token-id recipient))
    
    (map-set coupon-data token-id {
      merchant: merchant,
      discount-percentage: discount-percentage,
      expiry-block: expiry-block,
      max-uses: max-uses,
      current-uses: u0,
      is-active: true,
      coupon-type: coupon-type
    })
    
    (match (map-get? merchant-stats merchant)
      existing-stats
      (map-set merchant-stats merchant {
        total-coupons-issued: (+ (get total-coupons-issued existing-stats) u1),
        total-coupons-redeemed: (get total-coupons-redeemed existing-stats),
        total-discount-given: (get total-discount-given existing-stats)
      })
      (map-set merchant-stats merchant {
        total-coupons-issued: u1,
        total-coupons-redeemed: u0,
        total-discount-given: u0
      })
    )
    
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-public (redeem-coupon (token-id uint) (purchase-amount uint))
  (let 
    (
      (coupon-owner (unwrap! (nft-get-owner? coupon-nft token-id) err-coupon-not-found))
      (coupon-info (unwrap! (map-get? coupon-data token-id) err-coupon-not-found))
      (user tx-sender)
      (current-block stacks-block-height)
      (usage-key {token-id: token-id, user: user})
      (existing-usage (map-get? coupon-usage usage-key))
    )
    (asserts! (is-eq user coupon-owner) err-not-token-owner)
    (asserts! (get is-active coupon-info) err-coupon-already-used)
    (asserts! (<= current-block (get expiry-block coupon-info)) err-coupon-expired)
    (asserts! (< (get current-uses coupon-info) (get max-uses coupon-info)) err-coupon-already-used)
    
    (match existing-usage
      usage-data 
      (asserts! (not (get used usage-data)) err-coupon-already-used)
      true
    )
    
    (let 
      (
        (discount-amount (calculate-discount purchase-amount (get discount-percentage coupon-info)))
        (merchant (get merchant coupon-info))
        (new-uses (+ (get current-uses coupon-info) u1))
      )
      
      (map-set coupon-usage usage-key {
        used: true,
        used-block: current-block
      })
      
      (map-set coupon-data token-id (merge coupon-info {
        current-uses: new-uses,
        is-active: (< new-uses (get max-uses coupon-info))
      }))
      
      (match (map-get? merchant-stats merchant)
        existing-stats
        (map-set merchant-stats merchant {
          total-coupons-issued: (get total-coupons-issued existing-stats),
          total-coupons-redeemed: (+ (get total-coupons-redeemed existing-stats) u1),
          total-discount-given: (+ (get total-discount-given existing-stats) discount-amount)
        })
        true
      )
      
      (match (map-get? user-redemptions user)
        existing-redemptions
        (map-set user-redemptions user {
          total-redeemed: (+ (get total-redeemed existing-redemptions) u1),
          total-savings: (+ (get total-savings existing-redemptions) discount-amount)
        })
        (map-set user-redemptions user {
          total-redeemed: u1,
          total-savings: discount-amount
        })
      )
      
      (ok {
        discount-applied: discount-amount,
        final-amount: (- purchase-amount discount-amount),
        coupon-exhausted: (>= new-uses (get max-uses coupon-info))
      })
    )
  )
)

(define-public (deactivate-coupon (token-id uint))
  (let 
    (
      (coupon-info (unwrap! (map-get? coupon-data token-id) err-coupon-not-found))
      (merchant (get merchant coupon-info))
    )
    (asserts! (is-eq tx-sender merchant) err-unauthorized-merchant)
    
    (map-set coupon-data token-id (merge coupon-info {is-active: false}))
    (ok true)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? coupon-nft token-id sender recipient)
  )
)

(define-public (burn-coupon (token-id uint))
  (let 
    (
      (coupon-owner (unwrap! (nft-get-owner? coupon-nft token-id) err-coupon-not-found))
    )
    (asserts! (is-eq tx-sender coupon-owner) err-not-token-owner)
    (nft-burn? coupon-nft token-id coupon-owner)
  )
)

(define-read-only (get-contract-info)
  {
    name: "Expiring Coupon NFT Platform",
    version: "1.0.0",
    total-coupons: (var-get last-token-id)
  }
)

(define-read-only (get-coupon-summary (token-id uint))
  (match (map-get? coupon-data token-id)
    coupon-info
    (let 
      (
        (validity (is-coupon-valid token-id))
        (owner (nft-get-owner? coupon-nft token-id))
      )
      (ok {
        token-id: token-id,
        owner: owner,
        merchant: (get merchant coupon-info),
        discount: (get discount-percentage coupon-info),
        expiry-block: (get expiry-block coupon-info),
        current-uses: (get current-uses coupon-info),
        max-uses: (get max-uses coupon-info),
        valid: (get valid validity),
        type: (get coupon-type coupon-info)
      })
    )
    err-coupon-not-found
  )
)
