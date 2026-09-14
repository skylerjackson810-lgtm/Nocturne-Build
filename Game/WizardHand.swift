import RealityKit
import UIKit
import simd

@MainActor
enum WizardHand {
    static func build(in hand: Entity, holdingBook: Bool = false) throws {
        let leather = SimpleMaterial(color: UIColor(red: 0.21,green: 0.14,blue: 0.12,alpha: 1),roughness: 0.72,isMetallic: false)
        let inset = SimpleMaterial(color: UIColor(red: 0.12,green: 0.075,blue: 0.065,alpha: 1),roughness: 0.85,isMetallic: false)
        let cloth = SimpleMaterial(color: UIColor(red: 0.09,green: 0.075,blue: 0.18,alpha: 1),roughness: 1,isMetallic: false)
        let brass = SimpleMaterial(color: UIColor(red: 0.66,green: 0.46,blue: 0.21,alpha: 1),roughness: 0.38,isMetallic: true)
        try SceneDetail.sleeve(material: cloth,parent: hand)
        _ = SceneDetail.ellipsoid([0.047,0.024,0.061],at: [0,0,0],material: leather,parent: hand)
        _ = SceneDetail.ellipsoid([0.037,0.007,0.043],at: [0,0.020,0.005],material: inset,parent: hand)
        // Raised seam stitches follow the back of the glove.
        for side: Float in [-1,1] { for i in 0..<9 {
            _ = SceneDetail.rounded([0.003,0.002,0.006],at: [side*0.028,0.026,Float(i)*0.008-0.033],
                material: brass,parent: hand,radius: 0.0008)
        } }
        for i in 0..<4 {
            let finger = Entity(); finger.name = "Finger\(i)"
            finger.position = [Float(i)*0.023-0.0345,0,-0.039]; hand.addChild(finger)
            finger.orientation = simd_quatf(angle: holdingBook ? 0.55 : 0.10,axis: [1,0,0])
            let lengths: [Float] = [0.073,0.086,0.080,0.063]
            let length = lengths[i]
            var parent = finger
            for joint in 0..<3 {
                let segment = Entity(); segment.name = "Joint\(joint)"
                let fractions: [Float] = [0.43,0.34,0.23]
                let part = length*fractions[joint], radius = 0.010-Float(joint)*0.0012
                parent.addChild(segment)
                _ = SceneDetail.ellipsoid([radius,radius*0.9,part*0.59],at: [0,0,-part*0.5],material: leather,parent: segment)
                _ = SceneDetail.ellipsoid([radius*1.04,radius*0.96,radius],at: [0,0,0],material: leather,parent: segment)
                _ = SceneDetail.rounded([radius*1.25,0.003,0.009],at: [0,radius*0.85,-part*0.35],
                    material: inset,parent: segment,radius: 0.001)
                let next = Entity(); next.position.z = -part
                next.orientation = simd_quatf(angle: holdingBook ? 0.38 : -0.10,axis: [1,0,0])
                segment.addChild(next); parent = next
            }
        }
        let thumb = Entity(); thumb.position = [-0.039,-0.005,0.004]
        thumb.orientation = simd_quatf(angle: 0.90,axis: [0,1,0])*simd_quatf(angle: 0.25,axis: [1,0,0]); hand.addChild(thumb)
        _ = SceneDetail.ellipsoid([0.018,0.016,0.029],at: [0,0,-0.018],material: leather,parent: thumb)
        _ = SceneDetail.ellipsoid([0.012,0.012,0.025],at: [0,0.005,-0.052],material: leather,parent: thumb)
        for z: Float in [0.064,0.079] {
            _ = SceneDetail.rounded([0.124,0.012,0.009],at: [0,0.027,z],material: brass,parent: hand,radius: 0.003)
        }
        _ = SceneDetail.rounded([0.030,0.011,0.026],at: [0,0.033,0.071],material: brass,parent: hand,radius: 0.004)
        _ = SceneDetail.ellipsoid([0.009,0.007,0.011],at: [0,0.043,0.071],
            material: SimpleMaterial(color: UIColor(red: 0.36,green: 0.18,blue: 0.57,alpha: 1),roughness: 0.22,isMetallic: false),parent: hand)
    }
}
