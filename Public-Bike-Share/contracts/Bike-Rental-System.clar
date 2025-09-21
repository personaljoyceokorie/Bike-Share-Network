;; Decentralized Bike Sharing System Smart Contract
;; This contract manages bike rentals, payments, and operations across multiple cities
;; Features: bike registration, rental management, payment processing, and city operations

;; Error constants for various failure scenarios
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BIKE-NOT-FOUND (err u101))
(define-constant ERR-BIKE-NOT-AVAILABLE (err u102))
(define-constant ERR-BIKE-ALREADY-RENTED (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u104))
(define-constant ERR-RENTAL-NOT-FOUND (err u105))
(define-constant ERR-RENTAL-NOT-ACTIVE (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-CITY-NOT-FOUND (err u108))
(define-constant ERR-INVALID-COORDINATES (err u109))
(define-constant ERR-BIKE-ALREADY-EXISTS (err u110))
(define-constant ERR-INSUFFICIENT-BALANCE (err u111))
(define-constant ERR-TRANSFER-FAILED (err u112))
(define-constant ERR-INVALID-BIKE-TYPE (err u113))
(define-constant ERR-MAINTENANCE-MODE (err u114))
(define-constant ERR-RENTAL-EXPIRED (err u115))
(define-constant ERR-INVALID-INPUT (err u116))

;; Contract constants for operational parameters
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-RENTAL-DURATION u1440) ;; 24 hours in minutes
(define-constant MIN-RENTAL-DURATION u15) ;; 15 minutes minimum
(define-constant BASE-RATE u1000000) ;; 1 STX per hour base rate
(define-constant SECURITY-DEPOSIT u5000000) ;; 5 STX security deposit
(define-constant MAX-COORDINATE u360000) ;; Maximum coordinate value (360.000 degrees)
(define-constant MAX-RATE u1000000000) ;; Maximum hourly rate (1000 STX)
(define-constant MAX-CAPACITY u1000) ;; Maximum station capacity
(define-constant MAX-FEE-PERCENTAGE u50) ;; Maximum city fee percentage (50%)

;; Data variables for contract state management
(define-data-var next-bike-id uint u1)
(define-data-var next-rental-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var total-bikes uint u0)
(define-data-var total-rentals uint u0)

;; Data maps for storing bike information and state
(define-map bikes uint {
    owner: principal,
    bike-type: (string-ascii 20),
    city: (string-ascii 30),
    station-id: uint,
    latitude: uint,
    longitude: uint,
    hourly-rate: uint,
    available: bool,
    maintenance-mode: bool,
    total-rentals: uint,
    created-at: uint
})

;; Data map for active and historical rentals
(define-map rentals uint {
    bike-id: uint,
    renter: principal,
    start-time: uint,
    end-time: (optional uint),
    duration-minutes: uint,
    total-cost: uint,
    deposit-paid: uint,
    status: (string-ascii 10), ;; "active", "completed", "cancelled"
    start-latitude: uint,
    start-longitude: uint,
    end-latitude: (optional uint),
    end-longitude: (optional uint)
})

;; Data map for city information and operational parameters
(define-map cities (string-ascii 30) {
    active: bool,
    total-bikes: uint,
    total-stations: uint,
    base-rate: uint,
    city-fee-percentage: uint
})

;; Data map for bike station locations within cities
(define-map stations uint {
    city: (string-ascii 30),
    name: (string-ascii 50),
    latitude: uint,
    longitude: uint,
    capacity: uint,
    current-bikes: uint,
    active: bool
})

;; Data map to track user rental history and statistics
(define-map user-stats principal {
    total-rentals: uint,
    total-spent: uint,
    current-rental: (optional uint),
    reputation-score: uint,
    last-rental: (optional uint)
})

;; Data map for bike owner statistics and earnings
(define-map owner-stats principal {
    total-bikes: uint,
    total-earnings: uint,
    active-rentals: uint
})

;; Input validation helper functions
(define-private (validate-city-name (city (string-ascii 30)))
    (> (len city) u0)
)

(define-private (validate-station-name (name (string-ascii 50)))
    (> (len name) u0)
)

(define-private (validate-bike-type (bike-type (string-ascii 20)))
    (> (len bike-type) u0)
)

(define-private (validate-rate (rate uint))
    (and (> rate u0) (<= rate MAX-RATE))
)

(define-private (validate-capacity (capacity uint))
    (and (> capacity u0) (<= capacity MAX-CAPACITY))
)

(define-private (validate-fee-percentage (fee-percentage uint))
    (<= fee-percentage MAX-FEE-PERCENTAGE)
)

(define-private (validate-id (id uint))
    (> id u0)
)

;; Read-only function to get bike details by ID
(define-read-only (get-bike-info (bike-id uint))
    (map-get? bikes bike-id)
)

;; Read-only function to get rental details by ID
(define-read-only (get-rental-info (rental-id uint))
    (map-get? rentals rental-id)
)

;; Read-only function to get city information
(define-read-only (get-city-info (city (string-ascii 30)))
    (map-get? cities city)
)

;; Read-only function to get station information
(define-read-only (get-station-info (station-id uint))
    (map-get? stations station-id)
)

;; Read-only function to get user statistics
(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

;; Read-only function to get bike owner statistics
(define-read-only (get-owner-stats (owner principal))
    (map-get? owner-stats owner)
)

;; Read-only function to calculate rental cost based on duration and bike rate
(define-read-only (calculate-rental-cost (bike-id uint) (duration-minutes uint))
    (match (map-get? bikes bike-id)
        bike-data 
        (let ((hourly-rate (get hourly-rate bike-data))
              (hours (/ (+ duration-minutes u59) u60))) ;; Round up to next hour
            (ok (* hours hourly-rate)))
        ERR-BIKE-NOT-FOUND
    )
)

;; Read-only function to check if coordinates are within valid range
(define-read-only (validate-coordinates (latitude uint) (longitude uint))
    (and (<= latitude MAX-COORDINATE) (<= longitude MAX-COORDINATE))
)

;; Read-only function to get contract statistics
(define-read-only (get-contract-stats)
    {
        total-bikes: (var-get total-bikes),
        total-rentals: (var-get total-rentals),
        next-bike-id: (var-get next-bike-id),
        next-rental-id: (var-get next-rental-id),
        contract-paused: (var-get contract-paused)
    }
)

;; Public function to register a new city in the system
(define-public (register-city (city (string-ascii 30)) (base-rate uint) (fee-percentage uint))
    (let ((validated-city city)
          (validated-base-rate base-rate)
          (validated-fee-percentage fee-percentage))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (validate-city-name validated-city) ERR-INVALID-INPUT)
        (asserts! (validate-rate validated-base-rate) ERR-INVALID-INPUT)
        (asserts! (validate-fee-percentage validated-fee-percentage) ERR-INVALID-INPUT)
        (map-set cities validated-city {
            active: true,
            total-bikes: u0,
            total-stations: u0,
            base-rate: validated-base-rate,
            city-fee-percentage: validated-fee-percentage
        })
        (ok validated-city)
    )
)

;; Public function to add a bike station to a city
(define-public (add-station (station-id uint) (city (string-ascii 30)) (name (string-ascii 50)) 
                           (latitude uint) (longitude uint) (capacity uint))
    (let ((validated-station-id station-id)
          (validated-city city)
          (validated-name name)
          (validated-latitude latitude)
          (validated-longitude longitude)
          (validated-capacity capacity))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (validate-id validated-station-id) ERR-INVALID-INPUT)
        (asserts! (validate-city-name validated-city) ERR-INVALID-INPUT)
        (asserts! (validate-station-name validated-name) ERR-INVALID-INPUT)
        (asserts! (validate-coordinates validated-latitude validated-longitude) ERR-INVALID-COORDINATES)
        (asserts! (validate-capacity validated-capacity) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? cities validated-city)) ERR-CITY-NOT-FOUND)
        (map-set stations validated-station-id {
            city: validated-city,
            name: validated-name,
            latitude: validated-latitude,
            longitude: validated-longitude,
            capacity: validated-capacity,
            current-bikes: u0,
            active: true
        })
        ;; Update city station count
        (match (map-get? cities validated-city)
            city-data
            (map-set cities validated-city (merge city-data {total-stations: (+ (get total-stations city-data) u1)}))
            false
        )
        (ok validated-station-id)
    )
)

;; Public function to register a new bike in the system
(define-public (register-bike (bike-type (string-ascii 20)) (city (string-ascii 30)) 
                             (station-id uint) (latitude uint) (longitude uint) (hourly-rate uint))
    (let ((bike-id (var-get next-bike-id))
          (validated-bike-type bike-type)
          (validated-city city)
          (validated-station-id station-id)
          (validated-latitude latitude)
          (validated-longitude longitude)
          (validated-hourly-rate hourly-rate))
        (asserts! (not (var-get contract-paused)) ERR-MAINTENANCE-MODE)
        (asserts! (validate-bike-type validated-bike-type) ERR-INVALID-INPUT)
        (asserts! (validate-city-name validated-city) ERR-INVALID-INPUT)
        (asserts! (validate-id validated-station-id) ERR-INVALID-INPUT)
        (asserts! (validate-coordinates validated-latitude validated-longitude) ERR-INVALID-COORDINATES)
        (asserts! (validate-rate validated-hourly-rate) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? cities validated-city)) ERR-CITY-NOT-FOUND)
        (asserts! (is-some (map-get? stations validated-station-id)) ERR-CITY-NOT-FOUND)
        (asserts! (is-none (map-get? bikes bike-id)) ERR-BIKE-ALREADY-EXISTS)
        
        ;; Register the bike
        (map-set bikes bike-id {
            owner: tx-sender,
            bike-type: validated-bike-type,
            city: validated-city,
            station-id: validated-station-id,
            latitude: validated-latitude,
            longitude: validated-longitude,
            hourly-rate: validated-hourly-rate,
            available: true,
            maintenance-mode: false,
            total-rentals: u0,
            created-at: block-height
        })
        
        ;; Update counters and statistics
        (var-set next-bike-id (+ bike-id u1))
        (var-set total-bikes (+ (var-get total-bikes) u1))
        
        ;; Update city bike count
        (match (map-get? cities validated-city)
            city-data
            (map-set cities validated-city (merge city-data {total-bikes: (+ (get total-bikes city-data) u1)}))
            false
        )
        
        ;; Update station bike count
        (match (map-get? stations validated-station-id)
            station-data
            (map-set stations validated-station-id (merge station-data {current-bikes: (+ (get current-bikes station-data) u1)}))
            false
        )
        
        ;; Update owner statistics
        (match (map-get? owner-stats tx-sender)
            stats
            (map-set owner-stats tx-sender (merge stats {total-bikes: (+ (get total-bikes stats) u1)}))
            (map-set owner-stats tx-sender {total-bikes: u1, total-earnings: u0, active-rentals: u0})
        )
        
        (ok bike-id)
    )
)

;; Public function to start a bike rental
(define-public (start-rental (bike-id uint) (duration-minutes uint) (start-latitude uint) (start-longitude uint))
    (let ((rental-id (var-get next-rental-id))
          (current-time block-height)
          (validated-bike-id bike-id)
          (validated-duration-minutes duration-minutes)
          (validated-start-latitude start-latitude)
          (validated-start-longitude start-longitude))
        (asserts! (not (var-get contract-paused)) ERR-MAINTENANCE-MODE)
        (asserts! (validate-id validated-bike-id) ERR-INVALID-INPUT)
        (asserts! (validate-coordinates validated-start-latitude validated-start-longitude) ERR-INVALID-COORDINATES)
        (asserts! (and (>= validated-duration-minutes MIN-RENTAL-DURATION) 
                      (<= validated-duration-minutes MAX-RENTAL-DURATION)) ERR-INVALID-DURATION)
        
        ;; Verify bike exists and is available
        (match (map-get? bikes validated-bike-id)
            bike-data
            (begin
                (asserts! (get available bike-data) ERR-BIKE-NOT-AVAILABLE)
                (asserts! (not (get maintenance-mode bike-data)) ERR-MAINTENANCE-MODE)
                
                ;; Calculate total cost including deposit
                (match (calculate-rental-cost validated-bike-id validated-duration-minutes)
                    total-cost
                    (let ((total-payment (+ total-cost SECURITY-DEPOSIT)))
                        ;; Transfer payment from renter (STX transfer would be handled here)
                        ;; For this example, we assume payment validation
                        
                        ;; Create rental record
                        (map-set rentals rental-id {
                            bike-id: validated-bike-id,
                            renter: tx-sender,
                            start-time: current-time,
                            end-time: none,
                            duration-minutes: validated-duration-minutes,
                            total-cost: total-cost,
                            deposit-paid: SECURITY-DEPOSIT,
                            status: "active",
                            start-latitude: validated-start-latitude,
                            start-longitude: validated-start-longitude,
                            end-latitude: none,
                            end-longitude: none
                        })
                        
                        ;; Update bike availability
                        (map-set bikes validated-bike-id (merge bike-data {
                            available: false,
                            total-rentals: (+ (get total-rentals bike-data) u1)
                        }))
                        
                        ;; Update counters
                        (var-set next-rental-id (+ rental-id u1))
                        (var-set total-rentals (+ (var-get total-rentals) u1))
                        
                        ;; Update user statistics
                        (match (map-get? user-stats tx-sender)
                            stats
                            (map-set user-stats tx-sender (merge stats {
                                current-rental: (some rental-id),
                                total-rentals: (+ (get total-rentals stats) u1)
                            }))
                            (map-set user-stats tx-sender {
                                total-rentals: u1,
                                total-spent: u0,
                                current-rental: (some rental-id),
                                reputation-score: u100,
                                last-rental: none
                            })
                        )
                        
                        ;; Update owner statistics
                        (match (map-get? owner-stats (get owner bike-data))
                            owner-stat
                            (map-set owner-stats (get owner bike-data) 
                                    (merge owner-stat {active-rentals: (+ (get active-rentals owner-stat) u1)}))
                            false
                        )
                        
                        (ok rental-id)
                    )
                    err-code
                    (err err-code)
                )
            )
            ERR-BIKE-NOT-FOUND
        )
    )
)

;; Public function to end a bike rental
(define-public (end-rental (rental-id uint) (end-latitude uint) (end-longitude uint))
    (let ((current-time block-height)
          (validated-rental-id rental-id)
          (validated-end-latitude end-latitude)
          (validated-end-longitude end-longitude))
        (asserts! (validate-id validated-rental-id) ERR-INVALID-INPUT)
        (asserts! (validate-coordinates validated-end-latitude validated-end-longitude) ERR-INVALID-COORDINATES)
        
        ;; Verify rental exists and is active
        (match (map-get? rentals validated-rental-id)
            rental-data
            (begin
                (asserts! (is-eq (get renter rental-data) tx-sender) ERR-NOT-AUTHORIZED)
                (asserts! (is-eq (get status rental-data) "active") ERR-RENTAL-NOT-ACTIVE)
                
                ;; Update rental record
                (map-set rentals validated-rental-id (merge rental-data {
                    end-time: (some current-time),
                    status: "completed",
                    end-latitude: (some validated-end-latitude),
                    end-longitude: (some validated-end-longitude)
                }))
                
                ;; Make bike available again
                (match (map-get? bikes (get bike-id rental-data))
                    bike-data
                    (map-set bikes (get bike-id rental-data) (merge bike-data {
                        available: true,
                        latitude: validated-end-latitude,
                        longitude: validated-end-longitude
                    }))
                    false
                )
                
                ;; Update user statistics
                (match (map-get? user-stats tx-sender)
                    stats
                    (map-set user-stats tx-sender (merge stats {
                        current-rental: none,
                        total-spent: (+ (get total-spent stats) (get total-cost rental-data)),
                        last-rental: (some validated-rental-id)
                    }))
                    false
                )
                
                ;; Update owner earnings
                (match (map-get? bikes (get bike-id rental-data))
                    bike-data
                    (match (map-get? owner-stats (get owner bike-data))
                        owner-stat
                        (map-set owner-stats (get owner bike-data) (merge owner-stat {
                            total-earnings: (+ (get total-earnings owner-stat) (get total-cost rental-data)),
                            active-rentals: (- (get active-rentals owner-stat) u1)
                        }))
                        false
                    )
                    false
                )
                
                (ok validated-rental-id)
            )
            ERR-RENTAL-NOT-FOUND
        )
    )
)

;; Public function for bike owners to toggle maintenance mode
(define-public (toggle-bike-maintenance (bike-id uint))
    (let ((validated-bike-id bike-id))
        (asserts! (validate-id validated-bike-id) ERR-INVALID-INPUT)
        (match (map-get? bikes validated-bike-id)
            bike-data
            (begin
                (asserts! (is-eq (get owner bike-data) tx-sender) ERR-NOT-AUTHORIZED)
                (asserts! (get available bike-data) ERR-BIKE-ALREADY-RENTED) ;; Can't maintain rented bike
                (map-set bikes validated-bike-id (merge bike-data {
                    maintenance-mode: (not (get maintenance-mode bike-data))
                }))
                (ok (not (get maintenance-mode bike-data)))
            )
            ERR-BIKE-NOT-FOUND
        )
    )
)

;; Public function to update bike location (for owners)
(define-public (update-bike-location (bike-id uint) (new-latitude uint) (new-longitude uint) (new-station-id uint))
    (let ((validated-bike-id bike-id)
          (validated-new-latitude new-latitude)
          (validated-new-longitude new-longitude)
          (validated-new-station-id new-station-id))
        (asserts! (validate-id validated-bike-id) ERR-INVALID-INPUT)
        (asserts! (validate-coordinates validated-new-latitude validated-new-longitude) ERR-INVALID-COORDINATES)
        (asserts! (validate-id validated-new-station-id) ERR-INVALID-INPUT)
        (match (map-get? bikes validated-bike-id)
            bike-data
            (begin
                (asserts! (is-eq (get owner bike-data) tx-sender) ERR-NOT-AUTHORIZED)
                (asserts! (get available bike-data) ERR-BIKE-ALREADY-RENTED)
                (asserts! (is-some (map-get? stations validated-new-station-id)) ERR-CITY-NOT-FOUND)
                
                ;; Update old station count
                (match (map-get? stations (get station-id bike-data))
                    old-station
                    (map-set stations (get station-id bike-data) 
                            (merge old-station {current-bikes: (- (get current-bikes old-station) u1)}))
                    false
                )
                
                ;; Update new station count
                (match (map-get? stations validated-new-station-id)
                    new-station
                    (map-set stations validated-new-station-id 
                            (merge new-station {current-bikes: (+ (get current-bikes new-station) u1)}))
                    false
                )
                
                ;; Update bike location
                (map-set bikes validated-bike-id (merge bike-data {
                    latitude: validated-new-latitude,
                    longitude: validated-new-longitude,
                    station-id: validated-new-station-id
                }))
                (ok true)
            )
            ERR-BIKE-NOT-FOUND
        )
    )
)

;; Administrative function to pause/unpause contract
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok (var-get contract-paused))
    )
)

;; Administrative function to update base rental rate
(define-public (update-city-base-rate (city (string-ascii 30)) (new-rate uint))
    (let ((validated-city city)
          (validated-new-rate new-rate))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (validate-city-name validated-city) ERR-INVALID-INPUT)
        (asserts! (validate-rate validated-new-rate) ERR-INVALID-INPUT)
        (match (map-get? cities validated-city)
            city-data
            (begin
                (map-set cities validated-city (merge city-data {base-rate: validated-new-rate}))
                (ok validated-new-rate)
            )
            ERR-CITY-NOT-FOUND
        )
    )
)