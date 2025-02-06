;; Oracle Contract

(define-map price-feeds
  { token: principal }
  { price: uint, last-update: uint }
)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))

(define-public (update-price (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set price-feeds
      { token: token }
      { price: price, last-update: block-height }
    )
    (ok true)
  )
)

(define-read-only (get-price (token principal))
  (map-get? price-feeds { token: token })
)

