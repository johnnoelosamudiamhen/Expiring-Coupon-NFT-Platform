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
(define-constant err-listing-not-found (err u109))
(define-constant err-insufficient-payment (err u110))
(define-constant err-cannot-buy-own-listing (err u111))
(define-constant err-listing-expired (err u112))
(define-constant err-batch-limit-exceeded (err u113))
(define-constant err-batch-empty (err u114))
(define-constant err-invalid-time-range (err u115))
(define-constant err-analytics-not-found (err u116))
(define-constant err-invalid-category (err u117))

(define-data-var last-token-id uint u0)
(define-data-var last-listing-id uint u0)

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

(define-map marketplace-listings 
  uint 
  {
    token-id: uint,
    seller: principal,
    price: uint,
    listing-expiry: uint,
    is-active: bool
  }
)

(define-map listing-history 
  uint 
  {
    seller: principal,
    buyer: principal,
    price: uint,
    sold-block: uint
  }
)

;; === ANALYTICS & REPORTING SYSTEM ===

;; Daily analytics tracking
(define-map daily-analytics 
  uint ;; day (block-height / 144)
  {
    coupons-minted: uint,
    coupons-redeemed: uint,
    total-discount-given: uint,
    unique-users: uint,
    marketplace-sales: uint,
    avg-discount-percentage: uint
  }
)

;; Category performance tracking
(define-map category-analytics 
  (string-ascii 20) ;; coupon-type
  {
    total-minted: uint,
    total-redeemed: uint,
    total-discount-value: uint,
    avg-redemption-time: uint,
    conversion-rate: uint ;; (redeemed/minted) * 100
  }
)

;; Merchant performance detailed tracking
(define-map merchant-analytics 
  principal 
  {
    avg-discount-percentage: uint,
    most-popular-category: (string-ascii 20),
    total-revenue-impact: uint,
    customer-acquisition: uint,
    repeat-customers: uint
  }
)

;; User behavior analytics
(define-map user-analytics 
  principal 
  {
    avg-time-to-redeem: uint,
    favorite-category: (string-ascii 20),
    total-marketplace-purchases: uint,
    total-marketplace-sales: uint,
    loyalty-score: uint
  }
)

;; Time-based trend analysis
(define-map trend-analytics 
  {period: (string-ascii 10), period-number: uint} ;; {"daily", 123} or {"weekly", 52}
  {
    growth-rate: uint,
    popular-categories: (list 5 (string-ascii 20)),
    top-merchants: (list 5 principal),
    avg-discount-trend: uint
  }
)

;; Global platform analytics
(define-data-var total-platform-volume uint u0)
(define-data-var total-unique-users uint u0)
(define-data-var platform-launch-block uint u0)
(define-data-var analytics-enabled bool true)

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

(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? marketplace-listings listing-id)
)

(define-read-only (get-listing-history (listing-id uint))
  (map-get? listing-history listing-id)
)

(define-read-only (is-listing-valid (listing-id uint))
  (match (map-get? marketplace-listings listing-id)
    listing-info
    (let 
      (
        (current-block stacks-block-height)
        (coupon-validity (is-coupon-valid (get token-id listing-info)))
      )
      {
        valid: (and 
          (get is-active listing-info)
          (< current-block (get listing-expiry listing-info))
          (get valid coupon-validity)
        ),
        active: (get is-active listing-info),
        expired: (>= current-block (get listing-expiry listing-info)),
        coupon-valid: (get valid coupon-validity)
      }
    )
    {valid: false, active: false, expired: true, coupon-valid: false}
  )
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

(define-public (create-listing (token-id uint) (price uint) (listing-duration uint))
  (let 
    (
      (coupon-owner (unwrap! (nft-get-owner? coupon-nft token-id) err-coupon-not-found))
      (coupon-validity (is-coupon-valid token-id))
      (listing-id (+ (var-get last-listing-id) u1))
      (listing-expiry (+ stacks-block-height listing-duration))
    )
    (asserts! (is-eq tx-sender coupon-owner) err-not-token-owner)
    (asserts! (get valid coupon-validity) err-coupon-expired)
    (asserts! (> price u0) err-invalid-discount)
    (asserts! (> listing-duration u0) err-invalid-expiry)
    
    (map-set marketplace-listings listing-id {
      token-id: token-id,
      seller: tx-sender,
      price: price,
      listing-expiry: listing-expiry,
      is-active: true
    })
    
    (var-set last-listing-id listing-id)
    (ok listing-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let 
    (
      (listing-info (unwrap! (map-get? marketplace-listings listing-id) err-listing-not-found))
      (seller (get seller listing-info))
    )
    (asserts! (is-eq tx-sender seller) err-not-token-owner)
    (asserts! (get is-active listing-info) err-listing-expired)
    
    (map-set marketplace-listings listing-id (merge listing-info {is-active: false}))
    (ok true)
  )
)

(define-public (buy-coupon (listing-id uint))
  (let 
    (
      (listing-info (unwrap! (map-get? marketplace-listings listing-id) err-listing-not-found))
      (listing-validity (is-listing-valid listing-id))
      (token-id (get token-id listing-info))
      (seller (get seller listing-info))
      (price (get price listing-info))
      (buyer tx-sender)
    )
    (asserts! (get valid listing-validity) err-listing-expired)
    (asserts! (not (is-eq buyer seller)) err-cannot-buy-own-listing)
    
    (try! (stx-transfer? price buyer seller))
    (try! (nft-transfer? coupon-nft token-id seller buyer))
    
    (map-set marketplace-listings listing-id (merge listing-info {is-active: false}))
    
    (map-set listing-history listing-id {
      seller: seller,
      buyer: buyer,
      price: price,
      sold-block: stacks-block-height
    })
    
    (ok {
      token-id: token-id,
      seller: seller,
      buyer: buyer,
      price: price
    })
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

;; === ANALYTICS & REPORTING FUNCTIONS ===

;; Initialize platform analytics (owner only)
(define-public (initialize-analytics)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-launch-block stacks-block-height)
    (var-set total-platform-volume u0)
    (var-set total-unique-users u0)
    (ok true)
  )
)

;; Update daily analytics when events occur
(define-private (update-daily-analytics (mint-count uint) (redeem-count uint) (discount-amount uint) (new-user bool) (marketplace-sale uint))
  (let 
    (
      (current-day (/ stacks-block-height u144))
      (existing-data (default-to
        {coupons-minted: u0, coupons-redeemed: u0, total-discount-given: u0, unique-users: u0, marketplace-sales: u0, avg-discount-percentage: u0}
        (map-get? daily-analytics current-day)
      ))
    )
    (map-set daily-analytics current-day {
      coupons-minted: (+ (get coupons-minted existing-data) mint-count),
      coupons-redeemed: (+ (get coupons-redeemed existing-data) redeem-count),
      total-discount-given: (+ (get total-discount-given existing-data) discount-amount),
      unique-users: (+ (get unique-users existing-data) (if new-user u1 u0)),
      marketplace-sales: (+ (get marketplace-sales existing-data) marketplace-sale),
      avg-discount-percentage: (if (> (+ (get coupons-redeemed existing-data) redeem-count) u0)
        (/ (+ (get total-discount-given existing-data) discount-amount) (+ (get coupons-redeemed existing-data) redeem-count))
        u0
      )
    })
  )
)

;; Update category analytics
(define-private (update-category-analytics (coupon-type (string-ascii 20)) (is-mint bool) (is-redeem bool) (discount-value uint) (redemption-time uint))
  (let 
    (
      (existing-data (default-to
        {total-minted: u0, total-redeemed: u0, total-discount-value: u0, avg-redemption-time: u0, conversion-rate: u0}
        (map-get? category-analytics coupon-type)
      ))
      (new-minted (+ (get total-minted existing-data) (if is-mint u1 u0)))
      (new-redeemed (+ (get total-redeemed existing-data) (if is-redeem u1 u0)))
    )
    (map-set category-analytics coupon-type {
      total-minted: new-minted,
      total-redeemed: new-redeemed,
      total-discount-value: (+ (get total-discount-value existing-data) discount-value),
      avg-redemption-time: (if (> new-redeemed u0)
        (/ (+ (* (get avg-redemption-time existing-data) (get total-redeemed existing-data)) redemption-time) new-redeemed)
        u0
      ),
      conversion-rate: (if (> new-minted u0) (/ (* new-redeemed u100) new-minted) u0)
    })
  )
)

;; Get daily analytics report
(define-read-only (get-daily-analytics (day uint))
  (map-get? daily-analytics day)
)

;; Get analytics for current day
(define-read-only (get-current-day-analytics)
  (let 
    (
      (current-day (/ stacks-block-height u144))
    )
    (map-get? daily-analytics current-day)
  )
)

;; Get category performance report
(define-read-only (get-category-analytics (coupon-type (string-ascii 20)))
  (map-get? category-analytics coupon-type)
)

;; Get merchant detailed analytics
(define-read-only (get-merchant-analytics (merchant principal))
  (map-get? merchant-analytics merchant)
)

;; Get user behavior analytics
(define-read-only (get-user-analytics (user principal))
  (map-get? user-analytics user)
)

;; Get trend analytics for a specific period
(define-read-only (get-trend-analytics (period (string-ascii 10)) (period-number uint))
  (map-get? trend-analytics {period: period, period-number: period-number})
)

;; Get platform-wide analytics summary
(define-read-only (get-platform-analytics)
  {
    total-volume: (var-get total-platform-volume),
    total-unique-users: (var-get total-unique-users),
    total-coupons: (var-get last-token-id),
    total-listings: (var-get last-listing-id),
    launch-block: (var-get platform-launch-block),
    current-block: stacks-block-height,
    platform-age-days: (/ (- stacks-block-height (var-get platform-launch-block)) u144),
    analytics-enabled: (var-get analytics-enabled)
  }
)

;; Calculate conversion rate for a merchant
(define-read-only (calculate-merchant-conversion-rate (merchant principal))
  (match (map-get? merchant-stats merchant)
    stats
    (if (> (get total-coupons-issued stats) u0)
      (/ (* (get total-coupons-redeemed stats) u100) (get total-coupons-issued stats))
      u0
    )
    u0
  )
)

;; Get top performing categories (simplified version)
(define-read-only (get-category-performance-summary (category1 (string-ascii 20)) (category2 (string-ascii 20)) (category3 (string-ascii 20)))
  {
    category1: {
      name: category1,
      data: (map-get? category-analytics category1)
    },
    category2: {
      name: category2,
      data: (map-get? category-analytics category2)
    },
    category3: {
      name: category3,
      data: (map-get? category-analytics category3)
    }
  }
)

;; Calculate average discount across all redeemed coupons
(define-read-only (calculate-average-platform-discount)
  (let 
    (
      (current-day (/ stacks-block-height u144))
      (total-discount u0)
      (total-redemptions u0)
    )
    ;; This is a simplified calculation - in a full implementation, 
    ;; we would need to iterate through multiple days
    (match (map-get? daily-analytics current-day)
      day-data
      (if (> (get coupons-redeemed day-data) u0)
        (get avg-discount-percentage day-data)
        u0
      )
      u0
    )
  )
)

;; Generate weekly report (simplified for 7 days)
(define-read-only (generate-weekly-report)
  (let 
    (
      (current-day (/ stacks-block-height u144))
      (week-start (- current-day u7))
    )
    {
      start-day: week-start,
      end-day: current-day,
      current-day-data: (map-get? daily-analytics current-day),
      week-ago-data: (map-get? daily-analytics week-start),
      platform-summary: (get-platform-analytics)
    }
  )
)

;; Advanced analytics: Calculate user lifetime value
(define-read-only (calculate-user-lifetime-value (user principal))
  (match (map-get? user-redemptions user)
    redemption-data
    {
      total-savings: (get total-savings redemption-data),
      total-redemptions: (get total-redeemed redemption-data),
      avg-savings-per-redemption: (if (> (get total-redeemed redemption-data) u0)
        (/ (get total-savings redemption-data) (get total-redeemed redemption-data))
        u0
      )
    }
    {total-savings: u0, total-redemptions: u0, avg-savings-per-redemption: u0}
  )
)

;; Enhanced coupon effectiveness analysis
(define-read-only (analyze-coupon-effectiveness (token-id uint))
  (match (map-get? coupon-data token-id)
    coupon-info
    (let 
      (
        (time-to-expiry (- (get expiry-block coupon-info) stacks-block-height))
        (usage-rate (/ (* (get current-uses coupon-info) u100) (get max-uses coupon-info)))
        (is-expired (> stacks-block-height (get expiry-block coupon-info)))
      )
      (ok {
        token-id: token-id,
        merchant: (get merchant coupon-info),
        category: (get coupon-type coupon-info),
        discount-percentage: (get discount-percentage coupon-info),
        usage-rate: usage-rate,
        time-to-expiry: time-to-expiry,
        is-expired: is-expired,
        is-fully-utilized: (>= (get current-uses coupon-info) (get max-uses coupon-info)),
        effectiveness-score: (if is-expired
          usage-rate
          (/ (+ usage-rate (if (> time-to-expiry u0) u50 u0)) u2)
        )
      })
    )
    err-coupon-not-found
  )
)

;; Admin function to toggle analytics collection
(define-public (toggle-analytics (enabled bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set analytics-enabled enabled)
    (ok enabled)
  )
)
