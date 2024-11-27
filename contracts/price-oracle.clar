








;; Enhanced price-oracle.clar

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          CONSTANTS                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant max-stale-blocks u100) ;; Max blocks before price data is stale
(define-constant admin tx-sender)  ;; Replace with actual admin principal

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          DATA STORAGE                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Store the current BTC price in USD
(define-data-var btc-price uint u0)

;; Store the last update block
(define-data-var last-updated-block uint u0)

;; Store a manual block counter
(define-data-var manual-block-height uint u0)

;; Whitelist of authorized reporters
(define-map reporter-whitelist
    {reporter: principal}
    {is-authorized: bool})

;; Recent price submissions (for aggregation)
(define-map price-submissions
    {reporter: principal}
    {price: uint})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          PUBLIC FUNCTIONS                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Increment the manual block counter (called every block)
(define-public (increment-block-height)
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (var-set manual-block-height (+ (var-get manual-block-height) u1))
        (ok (var-get manual-block-height))
    ))

;; Add a reporter to the whitelist
(define-public (add-reporter (reporter principal))
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (map-set reporter-whitelist {reporter: reporter} {is-authorized: true})
        (ok true)
    ))

;; Remove a reporter from the whitelist
(define-public (remove-reporter (reporter principal))
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (map-delete reporter-whitelist {reporter: reporter})
        (ok true)
    ))

;; Submit a new BTC price (by authorized reporters)
(define-public (submit-price (price uint))
    (begin
        (asserts! (is-authorized tx-sender) (err "Unauthorized reporter"))
        (asserts! (> price u0) (err "Price must be greater than zero"))
        (map-set price-submissions {reporter: tx-sender} {price: price})
        (ok true)
    ))

;; Aggregate prices from reporters to update the official BTC price
;; Aggregate prices from reporters to update the official BTC price
(define-public (update-btc-price)
    (begin
        (asserts! (is-eq tx-sender admin) (err "Unauthorized"))
        (let ((prices (fetch-prices)))
            (asserts! (> (len prices) u0) (err "No valid price submissions"))
            (let ((average-price (calculate-average prices)))
                (var-set btc-price average-price)
                (var-set last-updated-block (var-get manual-block-height))
                (ok average-price)
            )
        )
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          READ-ONLY FUNCTIONS                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Get the current BTC price
(define-read-only (get-price)
    (var-get btc-price))

;; Get the last update block
(define-read-only (get-last-updated-block)
    (var-get last-updated-block))

;; Get the manual block height
(define-read-only (get-manual-block-height)
    (var-get manual-block-height))

;; Check if a reporter is authorized
(define-read-only (is-authorized (reporter principal))
    (default-to false (get is-authorized (map-get? reporter-whitelist {reporter: reporter}))))

;; Ensure price data is not stale (e.g., older than max-stale-blocks)
(define-read-only (is-price-stale)
    (>= (- (var-get manual-block-height) (var-get last-updated-block)) max-stale-blocks))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                          HELPERS                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Store price submissions directly in a list
(define-data-var price-list (list 200 uint) (list))

;; Fetch all submitted prices
(define-read-only (fetch-prices)
    (var-get price-list))



;; Calculate the average of a list of prices
(define-read-only (calculate-average (prices (list 200 uint)))
    (if (is-eq (len prices) u0)
        u0 ;; Return 0 if no prices exist
        (/ (fold + prices u0) (len prices))))
