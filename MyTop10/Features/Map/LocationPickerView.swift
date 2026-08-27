import SwiftUI
import MapKit

struct LocationPickerView: View {
    var onPick: (_ name: String, _ coordinate: CLLocationCoordinate2D, _ address: String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var pin = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @State private var placeName = ""
    @State private var address = ""
    @StateObject private var location = LocationPermissionService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    Marker("Pin", coordinate: pin)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    pin = context.camera.centerCoordinate
                    Task { await reverseGeocode() }
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    TextField("Place name", text: $placeName)
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(address.isEmpty ? "Move the map to choose a spot" : address)
                        .font(.custom("AvenirNext-Regular", size: 13))
                        .foregroundStyle(Theme.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Use this location") {
                        onPick(
                            placeName.isEmpty ? "Pinned place" : placeName,
                            pin,
                            address
                        )
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Pin a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("My location") {
                        location.requestWhenInUse()
                        location.startUpdatingIfAuthorized()
                        if let coord = location.lastLocation?.coordinate {
                            pin = coord
                            position = .region(
                                MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                )
                            )
                            Task { await reverseGeocode() }
                        }
                    }
                }
            }
            .onAppear {
                location.requestWhenInUse()
                location.startUpdatingIfAuthorized()
                if let coord = location.lastLocation?.coordinate {
                    pin = coord
                    position = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
            }
        }
    }

    private func reverseGeocode() async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return }
        address = [placemark.name, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        if placeName.isEmpty {
            placeName = placemark.name ?? placemark.locality ?? ""
        }
    }
}

struct ListMapView: View {
    let items: [TopTenItem]
    @Environment(\.dismiss) private var dismiss

    private var region: MKCoordinateRegion {
        let coords = items.compactMap(\.coordinate)
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
            )
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.05),
                longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.5, 0.05)
            )
        )
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(region)) {
                ForEach(items) { item in
                    if let coordinate = item.coordinate {
                        Marker("#\(item.rank) \(item.title)", coordinate: coordinate)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Top 10 Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
