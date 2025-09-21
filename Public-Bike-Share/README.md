# Decentralized Bike Sharing System

A smart contract built on the Stacks blockchain for managing a decentralized bike-sharing platform across multiple cities.

## Overview

This smart contract enables a peer-to-peer bike-sharing ecosystem where bike owners can register their bikes and earn rental income, while users can rent bikes for short-term transportation needs. The system operates across multiple cities with customizable pricing and fee structures.

## Features

- **Multi-city Support**: Register and operate bikes across different cities
- **Bike Registration**: Owners can register bikes with custom hourly rates
- **Station Management**: Organized bike stations with capacity tracking
- **Rental Management**: Complete rental lifecycle from start to completion
- **Payment Processing**: Built-in payment calculation with security deposits
- **Maintenance Mode**: Bike owners can toggle maintenance status
- **Statistics Tracking**: Comprehensive stats for users, owners, and system-wide metrics
- **Administrative Controls**: Contract pause functionality and rate management

## Contract Constants

### Error Codes
- `ERR-NOT-AUTHORIZED (100)`: Unauthorized access attempt
- `ERR-BIKE-NOT-FOUND (101)`: Bike ID does not exist
- `ERR-BIKE-NOT-AVAILABLE (102)`: Bike is currently rented or unavailable
- `ERR-BIKE-ALREADY-RENTED (103)`: Bike is already in active rental
- `ERR-INSUFFICIENT-PAYMENT (104)`: Payment amount is insufficient
- `ERR-RENTAL-NOT-FOUND (105)`: Rental ID does not exist
- `ERR-RENTAL-NOT-ACTIVE (106)`: Rental is not in active status
- `ERR-INVALID-DURATION (107)`: Rental duration outside allowed range
- `ERR-CITY-NOT-FOUND (108)`: City is not registered in the system
- `ERR-INVALID-COORDINATES (109)`: GPS coordinates are out of valid range
- `ERR-BIKE-ALREADY-EXISTS (110)`: Bike ID already registered
- `ERR-INSUFFICIENT-BALANCE (111)`: User has insufficient balance
- `ERR-TRANSFER-FAILED (112)`: STX transfer operation failed
- `ERR-INVALID-BIKE-TYPE (113)`: Bike type is not supported
- `ERR-MAINTENANCE-MODE (114)`: Operation blocked due to maintenance
- `ERR-RENTAL-EXPIRED (115)`: Rental has exceeded maximum duration

### Operational Parameters
- **Base Rate**: 1 STX per hour default rental rate
- **Security Deposit**: 5 STX required for each rental
- **Rental Duration**: 15 minutes minimum, 1440 minutes (24 hours) maximum
- **Coordinate Range**: 0 to 360.000 degrees for latitude/longitude

## Data Structures

### Bikes
Each bike contains:
- Owner principal address
- Bike type (string, max 20 characters)
- City location (string, max 30 characters)
- Station ID and GPS coordinates
- Hourly rental rate
- Availability and maintenance status
- Total rentals count and creation timestamp

### Rentals
Each rental record includes:
- Bike ID and renter principal
- Start/end timestamps and location coordinates
- Duration in minutes and total cost
- Security deposit amount and rental status
- Complete location tracking (start/end coordinates)

### Cities
City configuration contains:
- Active status and total bikes/stations count
- Base rental rate and city fee percentage

### Stations
Station information includes:
- City association and station name
- GPS coordinates and bike capacity
- Current bike count and active status

### User Statistics
User profiles track:
- Total rentals and amount spent
- Current active rental ID
- Reputation score and last rental timestamp

### Owner Statistics
Bike owner metrics include:
- Total bikes owned and earnings generated
- Current active rentals count

## Public Functions

### City and Station Management

#### `register-city`
```clarity
(register-city (city (string-ascii 30)) (base-rate uint) (fee-percentage uint))
```
Register a new city in the system (admin only).

#### `add-station`
```clarity
(add-station (station-id uint) (city (string-ascii 30)) (name (string-ascii 50)) (latitude uint) (longitude uint) (capacity uint))
```
Add a new bike station to a registered city (admin only).

### Bike Management

#### `register-bike`
```clarity
(register-bike (bike-type (string-ascii 20)) (city (string-ascii 30)) (station-id uint) (latitude uint) (longitude uint) (hourly-rate uint))
```
Register a new bike in the system. Any user can register their bike.

#### `toggle-bike-maintenance`
```clarity
(toggle-bike-maintenance (bike-id uint))
```
Toggle maintenance mode for a bike (owner only, bike must be available).

#### `update-bike-location`
```clarity
(update-bike-location (bike-id uint) (new-latitude uint) (new-longitude uint) (new-station-id uint))
```
Update bike location and station assignment (owner only, bike must be available).

### Rental Operations

#### `start-rental`
```clarity
(start-rental (bike-id uint) (duration-minutes uint) (start-latitude uint) (start-longitude uint))
```
Start a new bike rental. Requires payment of rental cost plus security deposit.

#### `end-rental`
```clarity
(end-rental (rental-id uint) (end-latitude uint) (end-longitude uint))
```
Complete an active rental by providing end location coordinates.

### Administrative Functions

#### `toggle-contract-pause`
```clarity
(toggle-contract-pause)
```
Pause or unpause the entire contract (admin only).

#### `update-city-base-rate`
```clarity
(update-city-base-rate (city (string-ascii 30)) (new-rate uint))
```
Update the base rental rate for a specific city (admin only).

## Read-Only Functions

### Information Retrieval
- `get-bike-info (bike-id uint)`: Retrieve complete bike information
- `get-rental-info (rental-id uint)`: Get rental details by ID
- `get-city-info (city (string-ascii 30))`: Fetch city configuration
- `get-station-info (station-id uint)`: Get station details
- `get-user-stats (user principal)`: Retrieve user statistics
- `get-owner-stats (owner principal)`: Get bike owner statistics
- `get-contract-stats`: System-wide statistics and counters

### Utility Functions
- `calculate-rental-cost (bike-id uint) (duration-minutes uint)`: Calculate rental cost
- `validate-coordinates (latitude uint) (longitude uint)`: Validate GPS coordinates

## Usage Examples

### Registering a City (Admin)
```clarity
(contract-call? .bike-sharing register-city "New York" u1000000 u10)
```

### Adding a Station (Admin)
```clarity
(contract-call? .bike-sharing add-station u1 "New York" "Central Park Station" u40750000 u73970000 u20)
```

### Registering a Bike
```clarity
(contract-call? .bike-sharing register-bike "Electric" "New York" u1 u40750000 u73970000 u1500000)
```

### Starting a Rental
```clarity
(contract-call? .bike-sharing start-rental u1 u120 u40750100 u73970100)
```

### Ending a Rental
```clarity
(contract-call? .bike-sharing end-rental u1 u40750200 u73970200)
```

## Security Considerations

1. **Authorization**: All sensitive operations require proper authorization checks
2. **Input Validation**: Coordinates, durations, and rates are validated before processing
3. **State Consistency**: Bike availability and rental status are consistently maintained
4. **Deposit System**: Security deposits protect against bike theft or damage
5. **Maintenance Mode**: Bikes can be temporarily removed from service
6. **Contract Pause**: Emergency pause functionality for system maintenance

## Coordinate System

The contract uses a scaled integer coordinate system:
- Coordinates are stored as integers multiplied by 1000
- Example: 40.750 degrees latitude = 40750000 in the contract
- Maximum coordinate value: 360000000 (360.000 degrees)

## Payment Structure

- **Rental Cost**: Calculated based on bike's hourly rate and rental duration (rounded up to next hour)
- **Security Deposit**: Fixed 5 STX deposit required for all rentals
- **City Fees**: Configurable percentage fee that cities can charge
- **Owner Earnings**: Rental payments minus city fees go to bike owners

## Development and Deployment

This smart contract is written in Clarity for the Stacks blockchain. To deploy:

1. Ensure you have the Stacks CLI installed
2. Test the contract on testnet first
3. Deploy using the Stacks deployment tools
4. Initialize cities and stations after deployment