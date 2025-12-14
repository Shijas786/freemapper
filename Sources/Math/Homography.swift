import Foundation
import simd

struct Homography {
    
    // Solves for H where dst = H * src
    // We strictly need 4 points.
    static func compute(src pointsSrc: [SIMD2<Float>], dst pointsDst: [SIMD2<Float>]) -> simd_float3x3 {
        guard pointsSrc.count == 4, pointsDst.count == 4 else { return matrix_identity_float3x3 }
        
        var P: [Float] = []
        // System of equations for H = [h0, h1, h2; h3, h4, h5; h6, h7, 1]
        // x' = (h0x + h1y + h2) / (h6x + h7y + 1)
        // y' = (h3x + h4y + h5) / (h6x + h7y + 1)
        
        for i in 0..<4 {
            let s = pointsSrc[i] // x, y
            let d = pointsDst[i] // x', y'
            
            // Equation 1 for x'
            // h0*x + h1*y + h2 - h6*x*x' - h7*y*x' = x'
            P.append(contentsOf: [s.x, s.y, 1, 0, 0, 0, -s.x * d.x, -s.y * d.x])
            
            // Equation 2 for y'
            // h3*x + h4*y + h5 - h6*x*y' - h7*y*y' = y'
            P.append(contentsOf: [0, 0, 0, s.x, s.y, 1, -s.x * d.y, -s.y * d.y])
        }
        
        // Solve A * h = B
        // A is 8x8 (P), B is 8x1 (dst coordinates serialized)
        
        // Create matrices for LAPACK / Accelerate or manual Gaussian
        // For minimal dependency and 8x8, we can use a simple swift gaussian implementation or unsafe Accelerate.
        // Given constraints, I'll write a tiny Gaussian elimination here to be "Self contained" and "Real code".
        
        var A = P
        var B: [Float] = pointsDst.flatMap { [$0.x, $0.y] }
        
        guard let X = solveSystem(A: A, B: B, n: 8) else {
            return matrix_identity_float3x3
        }
        
        return simd_float3x3(
            SIMD3<Float>(X[0], X[3], X[6]),
            SIMD3<Float>(X[1], X[4], X[7]),
            SIMD3<Float>(X[2], X[5], 1.0)
        )
    }
    
    // Gaussian Elimination with Partial Pivoting
    private static func solveSystem(A: [Float], B: [Float], n: Int) -> [Float]? {
        var mat = A
        var rhs = B
        var x = [Float](repeating: 0, count: n)
        
        // Access helper
        func at(_ r: Int, _ c: Int) -> Int { return r * n + c }
        
        for i in 0..<n {
            // pivot
            var pivotRow = i
            for k in i+1..<n {
                if abs(mat[at(k, i)]) > abs(mat[at(pivotRow, i)]) {
                    pivotRow = k
                }
            }
            
            // swap
            for k in i..<n {
                let temp = mat[at(i, k)]
                mat[at(i, k)] = mat[at(pivotRow, k)]
                mat[at(pivotRow, k)] = temp
            }
            let tempB = rhs[i]
            rhs[i] = rhs[pivotRow]
            rhs[pivotRow] = tempB
            
            if abs(mat[at(i, i)]) < 1e-6 { return nil } // Singular
            
            // eliminate
            for k in i+1..<n {
                let factor = mat[at(k, i)] / mat[at(i, i)]
                for j in i..<n {
                    mat[at(k, j)] -= factor * mat[at(i, j)]
                }
                rhs[k] -= factor * rhs[i]
            }
        }
        
        // back sub
        for i in (0..<n).reversed() {
            var sum: Float = 0
            for j in i+1..<n {
                sum += mat[at(i, j)] * x[j]
            }
            x[i] = (rhs[i] - sum) / mat[at(i, i)]
        }
        
        return x
    }
}
