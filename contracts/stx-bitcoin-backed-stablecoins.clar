;; stx-bitcoin-backed-stablecoins


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          CONSTANTS                           ;;
;;;;;;;;;;;;;ss;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (define-constant min-collateral-ratio u150) 
(define-data-var min-collateral-ratio uint u150) ;; Dynamically adjustable


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          DATA STORAGE                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-map collateral-map
    {user: principal}      
    {btc: uint})           

(define-map stablecoin-balance
    {user: principal}      
    {balance: uint})    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          READ-ONLY FUNCTIONS                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Get the collateral (BTC) locked by a specific user
(define-read-only (get-collateral (user principal))
    (default-to u0 (get btc (map-get? collateral-map {user: user}))))

;; Get the stablecoin balance of a specific user
(define-read-only (get-stablecoin-balance (user principal))
    (default-to u0 (get balance (map-get? stablecoin-balance {user: user}))))

;;Fetch the current Bitcoin price from the oracle
(define-read-only (get-btc-price)
    ;; Replace `.price-oracle` and `get-price` with the actual oracle contract and function
    (contract-call? .price-oracle get-price))

;; Calculate the USD value of a given BTC amount
(define-read-only (calculate-collateral-value (btc-amount uint))
    (let ((btc-price (get-btc-price)))
        (* btc-amount btc-price)))

;; Check if the user's collateral is sufficient to mint a specified amount of stablecoins
(define-read-only (is-collateral-sufficient (user principal) (mint-amount uint))
    (let ((collateral (get-collateral user))
          (btc-price (get-btc-price))
          (min-ratio (var-get min-collateral-ratio))) ;; Fetch min-collateral-ratio
        (>= (* collateral btc-price) (* mint-amount (/ min-ratio u100)))))

;; Check the collateralization ratio of a specific user
(define-read-only (check-collateral-ratio (user principal))
    (let ((collateral (get-collateral user))
          (balance (get-stablecoin-balance user))
          (btc-price (get-btc-price)))
        (if (is-eq balance u0)
            (err "No stablecoins minted")
            (ok (/ (* collateral btc-price) balance)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          PUBLIC FUNCTIONS                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Lock collateral (BTC) to back stablecoins
(define-public (lock-collateral (btc-amount uint))
    (begin
        (asserts! (> btc-amount u0) (err "BTC amount must be greater than zero"))
        ;; Update the collateral map
        (map-insert collateral-map 
                    {user: tx-sender} 
                    {btc: (+ btc-amount (default-to u0 (get btc (map-get? collateral-map {user: tx-sender}))))})
        (ok btc-amount)
    ))

;; Mint stablecoins if sufficient collateral is provided
(define-public (mint-stablecoin (amount uint))
    (begin
        (asserts! (> amount u0) (err "Mint amount must be greater than zero"))
        (asserts! (is-collateral-sufficient tx-sender amount) (err "Insufficient collateral"))
        ;; Mint stablecoins by increasing the user's balance
        (map-set stablecoin-balance
                 {user: tx-sender}
                 {balance: (+ amount (default-to u0 (get balance (map-get? stablecoin-balance {user: tx-sender}))))})
        (ok amount)
    ))



;; Burn stablecoins and unlock corresponding BTC collateral
(define-public (burn-stablecoin (amount uint))
    (begin
        (asserts! (> amount u0) (err "Burn amount must be greater than zero"))
        (let ((balance (get-stablecoin-balance tx-sender)))
            (asserts! (>= balance amount) (err "Not enough stablecoins"))
            ;; Decrease stablecoin balance
            (map-set stablecoin-balance {user: tx-sender} {balance: (- balance amount)})
            ;; Unlock collateral equivalent to burned stablecoins
            (let ((btc-price  (get-btc-price)))
                (let ((collateral-to-unlock (/ amount btc-price)))
                    (map-set collateral-map
                             {user: tx-sender}
                             {btc: (- (get-collateral tx-sender) collateral-to-unlock)})
                    (ok collateral-to-unlock)
                )
            )
        )
    ))

;; Liquidate under-collateralized positions
(define-public (liquidate (user principal))
    (begin
        (let ((collateral (get-collateral user))
              (balance (get-stablecoin-balance user))
              (btc-price (get-btc-price))
              (min-ratio (var-get min-collateral-ratio))) ;; Fetch min-collateral-ratio
            ;; Check if under-collateralized
            (asserts! (< (* collateral btc-price) (* balance (/ min-ratio u100))) (err "Position is not under-collateralized"))
            ;; Liquidate the user's position
            (map-delete collateral-map {user: user})
            (map-delete stablecoin-balance {user: user})
            (ok true)
        )
    ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          CONSTANTS                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant admin tx-sender) ;; Replace with admin principal
(define-data-var system-paused bool false) ;; Pause system operations

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          DATA STORAGE                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(define-map interest-earned
    {user: principal}
    {earned: uint})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          READ-ONLY FUNCTIONS                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Check if the system is paused
(define-read-only (is-paused)
    (var-get system-paused))

;; Get dynamic minimum collateral ratio
(define-read-only (get-min-collateral-ratio)
    (var-get min-collateral-ratio))


(define-public (adjust-collateral-ratio (new-ratio uint))
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (asserts! (> new-ratio u100) (err "Collateral ratio must be greater than 100%"))
        (var-set min-collateral-ratio new-ratio)
        (ok new-ratio)
    ))



;; Admin: Pause system
(define-public (pause-system)
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (var-set system-paused true)
        (ok true)
    ))

;; Admin: Unpause system
(define-public (unpause-system)
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (var-set system-paused false)
        (ok true)
    ))

;; Withdraw excess collateral
(define-public (withdraw-collateral (btc-amount uint))
    (begin
        (asserts! (not (is-paused)) (err "System is paused"))
        (asserts! (> btc-amount u0) (err "BTC amount must be greater than zero"))
        (let ((collateral (get-collateral tx-sender))
              (balance (get-stablecoin-balance tx-sender))
              (btc-price (get-btc-price))
              (min-collateral (* balance (/ (var-get min-collateral-ratio) u100))))
            (asserts! (> collateral min-collateral) (err "Not enough excess collateral"))
            (let ((withdrawable (- collateral min-collateral)))
                (asserts! (>= withdrawable btc-amount) (err "Requested amount exceeds excess collateral"))
                (map-set collateral-map
                         {user: tx-sender}
                         {btc: (- collateral btc-amount)})
                (ok btc-amount)
            )
        )
    ))

;; Claim earned interest
(define-public (claim-interest)
    (begin
        (asserts! (not (is-paused)) (err "System is paused"))
        (let ((earned (default-to u0 (get earned (map-get? interest-earned {user: tx-sender})))))
            (asserts! (> earned u0) (err "No interest to claim"))
            (map-set interest-earned {user: tx-sender} {earned: u0})
            (ok earned)
        )
    ))

