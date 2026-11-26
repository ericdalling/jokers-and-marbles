/// Visual orientation only: never changes the underlying board or move rules.
public enum BoardOrientation {
    /// Seats are numbered clockwise from 0 through 5.
    /// Returns the shortest rotation in degrees, including wraparound.
    public static func shortestRotation(from currentSeat: Int, to activeSeat: Int, seatCount: Int = 6) -> Double {
        guard seatCount > 0 else { return 0 }
        let current = ((currentSeat % seatCount) + seatCount) % seatCount
        let target = ((activeSeat % seatCount) + seatCount) % seatCount
        let step = 360.0 / Double(seatCount)
        var delta = Double(target - current) * step
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}
