;; Farm Contract

(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u100)  ;; 100 reward tokens per block
(define-data-var last-update-time uint u0)

(define-map user-stakes
  { user: principal }
  { amount: uint, reward-debt: uint }
)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))

(define-public (stake (amount uint))
  (let
    ((user-stake (default-to { amount: u0, reward-debt: u0 } (map-get? user-stakes { user: tx-sender }))))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-stakes
      { user: tx-sender }
      {
        amount: (+ (get amount user-stake) amount),
        reward-debt: (+ (get reward-debt user-stake) (calculate-rewards tx-sender))
      }
    )
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set last-update-time block-height)
    (ok true)
  )
)

(define-public (unstake (amount uint))
  (let
    ((user-stake (unwrap! (map-get? user-stakes { user: tx-sender }) ERR_UNAUTHORIZED)))
    (asserts! (<= amount (get amount user-stake)) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-stakes
      { user: tx-sender }
      {
        amount: (- (get amount user-stake) amount),
        reward-debt: (+ (get reward-debt user-stake) (calculate-rewards tx-sender))
      }
    )
    (var-set total-staked (- (var-get total-staked) amount))
    (var-set last-update-time block-height)
    (ok true)
  )
)

(define-public (claim-rewards)
  (let
    ((rewards (calculate-rewards tx-sender))
     (user-stake (unwrap! (map-get? user-stakes { user: tx-sender }) ERR_UNAUTHORIZED)))
    (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
    (map-set user-stakes
      { user: tx-sender }
      (merge user-stake { reward-debt: (+ (get reward-debt user-stake) rewards) })
    )
    (var-set last-update-time block-height)
    (ok rewards)
  )
)

(define-read-only (get-user-stake (user principal))
  (map-get? user-stakes { user: user })
)

(define-read-only (calculate-rewards (user principal))
  (let
    ((user-stake (default-to { amount: u0, reward-debt: u0 } (map-get? user-stakes { user: user })))
     (time-elapsed (- block-height (var-get last-update-time))))
    (if (is-eq (var-get total-staked) u0)
      u0
      (/ (* (* (get amount user-stake) (var-get reward-rate)) time-elapsed) (var-get total-staked))
    )
  )
)

(define-public (update-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set reward-rate new-rate)
    (ok true)
  )
)

