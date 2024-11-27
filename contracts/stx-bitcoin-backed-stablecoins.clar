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
