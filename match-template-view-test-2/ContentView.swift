import SwiftUI
import PhotosUI
import AlertKit

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum HandleSizes: CGFloat {
    case sign = 6
    case visible = 30
    case safeArea = 50
}

struct ButtonStyled: View {
    enum Importance {
        case primary
        case secondary
    }
    
    enum Padding {
        case leadingPadding
        case trailingPadding
    }
    
    var icon: String
    var text: String
    var importance: Importance
    var padding: Padding
    var hideText: Bool
    var isShrinkened: Bool
    var action: ()->() = {}
    
    init(
        _ icon: String,
        _ text: String,
        _ padding: Padding = .leadingPadding,
        _is: Importance = .primary,
        hideText: Bool = false,
        isShrinkened: Bool = false,
        action: @escaping ()->() = {})
    {
        self.icon = icon
        self.text = text
        self.importance = _is
        self.padding = padding
        self.hideText = hideText
        self.isShrinkened = isShrinkened
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon + ".fill")
                    .font(.system(size: 16))
                if !hideText {
                    Text(text)
                        .font(.system(size: 14))
                        .transition(.move(edge: .leading))
                }
            }
            .frame(maxWidth: isShrinkened ? .zero : .infinity)
            .padding()
            .padding(.leading, 15).padding(.trailing, 15)
            .background(importance == .secondary ? .blue.opacity(0.15) : .blue)
            .foregroundColor(importance == .secondary ? .blue : .white)
            .cornerRadius(8)
            .opacity(1)
            .controlSize(.large)
        }
    }
}

struct CropHandlePositions {
    struct Position {
        var initial: CGFloat
        var current: CGFloat

        var _min: CGFloat {
            return min(initial, current)
        }
        
        var _max: CGFloat {
            return max(initial, current)
        }
    }

    var top: Position
    var bottom: Position

    init(_ _initialTop: CGFloat, _ _initialBottom: CGFloat) {
        self.top = Position(initial: _initialTop, current: _initialTop)
        self.bottom = Position(initial: _initialBottom, current: _initialBottom)
    }

    var p: [String: Position] {
        get {
            return [
                "top": top,
                "bottom": bottom
            ]
        }
        set {
            if let newTop = newValue["top"] {
                var updatedTop = newTop
                if updatedTop.current >= bottom.current {
                    updatedTop.current = bottom.current
                }
                top = updatedTop
            }
            if let newBottom = newValue["bottom"] {
                var updatedBottom = newBottom
                if updatedBottom.current <= top.current {
                    updatedBottom.current = top.current
                }
                bottom = updatedBottom
            }
        }
    }
}

struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var handlePositions: [Int: CropHandlePositions]
    @Binding var cropperOpenTimesCount: Int
    @State private var cropHandleIsMoving: Bool = false
    
    enum CropHandleSides: String {
        case top
        case bottom
    }
    
    init(cropperOpenTimesCount: Binding<Int>, _ displayImages: Binding<[UIImage]>, _ handlePositions: Binding<[Int: CropHandlePositions]>) {
        self._displayImages = displayImages
        self._handlePositions = handlePositions
        self._cropperOpenTimesCount = cropperOpenTimesCount
    }
    
    private func calculatedOffsetForImageCroppingOverlay(for index: Int, side: CropHandleSides) -> CGSize {
        let current = handlePositions[index]?.p[side.rawValue]?.current ?? 0
        let initial = handlePositions[index]?.p[side.rawValue]?.initial ?? 0
        let offset = -(initial-current)/2
        return CGSize(width: 0, height: offset)
    }
    
    private func calculatedHeightForImageCroppingOverlay(for index: Int, side: CropHandleSides) -> CGFloat {
        let _min = handlePositions[index]?.p[side.rawValue]?._min ?? 0
        let _max = handlePositions[index]?.p[side.rawValue]?._max ?? 0
        return _max - _min
    }
    
    private func calculatedPositionForImageCroppingOverlay(for index: Int, side: CropHandleSides) -> CGFloat {
        let initial = handlePositions[index]?.p[side.rawValue]?.initial ?? 0
        return initial
    }
    
    private func getCropHandleView(side: CropHandleSides, geometry: GeometryProxy, handlePositions: [Int: CropHandlePositions], index: Int) -> some View {

        return ZStack{
        Rectangle()
            .fill(Color("overlay-crop-color"))
            .frame(
                width: geometry.size.width,
                height: calculatedHeightForImageCroppingOverlay(for: index, side: side)
            )
            .position(
                x: geometry.size.width / 2,
                y: calculatedPositionForImageCroppingOverlay(for: index, side: side)
            )
            .offset(calculatedOffsetForImageCroppingOverlay(for: index, side: side))

        ZStack {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: HandleSizes.visible.rawValue, height: HandleSizes.visible.rawValue)
                Circle()
                    .fill(.white)
                    .frame(width: HandleSizes.sign.rawValue, height: HandleSizes.sign.rawValue)
            }
            .scaleEffect(
                CGSize(
                    width: cropHandleIsMoving ? 0 : 1,
                    height: cropHandleIsMoving ? 0 : 1
                ), anchor: .center
            )
                
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
        }
        .frame(width: geometry.size.width, height: HandleSizes.safeArea.rawValue, alignment: .center)
        .position(
            x: geometry.size.width / 2,
            y: handlePositions[index]?.p[side.rawValue]?.current ?? 0
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    self.handlePositions[index]?.p[side.rawValue]?.current = value.location.y
                    withAnimation(.linear(duration: 0.05)) {
                        cropHandleIsMoving = true
                    }
                }
                .onEnded { value in
                    withAnimation(.linear(duration: 0.05)) {
                        cropHandleIsMoving = false
                    }
                }
        )
        }
    }

    var body: some View {
        if cropperOpenTimesCount > 0 {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(displayImages.indices, id: \.self) { (index: Range<Array<UIImage>.Index>.Element) in
                                ZStack {
                                    Image(uiImage: displayImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .background(GeometryReader { proxy in
                                        Color.clear
                                            .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .global).origin.x)
                                        })
                                        .onAppear{
                                            let imageSize = calculateImageSize(for: displayImages[index], in: geometry.size)
                                            let topPositionY = (geometry.size.height - imageSize.height) / 2
                                            let bottomPositionY = topPositionY + imageSize.height
                                            handlePositions[index] = CropHandlePositions(topPositionY, bottomPositionY)
                                        }
                                    
                                    getCropHandleView(side: .top, geometry: geometry, handlePositions: handlePositions, index: index)
                                    
                                    getCropHandleView(side: .bottom, geometry: geometry, handlePositions: handlePositions, index: index)
                                }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
                .scrollClipDisabled(true)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scrollTargetLayout()
                .scrollTargetBehavior(.viewAligned)
                .onPreferenceChange(ScrollOffsetKey.self) { _ in
                    withAnimation(.linear(duration: 0.25)){
                        cropHandleIsMoving = false
                    }
                }
            }
        }
    }
    
    private func calculateImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let aspectRatio = image.size.width / image.size.height
        if containerSize.width / containerSize.height > aspectRatio {
            let height = containerSize.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        } else {
            let width = containerSize.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }
}


struct PhotosPickerView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var displayImages: [UIImage]
    @Binding var handlePositions: [Int: CropHandlePositions]
    @Binding var cropperOpenTimesCount: Int
    
    init(cropperOpenTimesCount: Binding<Int>, _ selectedItems: Binding<[PhotosPickerItem]>, _ displayImages: Binding<[UIImage]>, _ handlePositions: Binding<[Int: CropHandlePositions]>) {
            self._selectedItems = selectedItems
            self._displayImages = displayImages
            self._handlePositions = handlePositions
            self._cropperOpenTimesCount = cropperOpenTimesCount
        }
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            selectionBehavior: .ordered,
            matching: .not(.any(of: [.bursts, .cinematicVideos, .depthEffectPhotos, .livePhotos, .screenRecordings, .screenRecordings, .slomoVideos, .timelapseVideos, .videos])),
            photoLibrary: .shared()) {
                HStack{
                    ButtonStyled("photo", "Pick a photo", _is:  cropperOpenTimesCount > 0 ? .secondary : .primary, hideText: cropperOpenTimesCount > 0, isShrinkened: cropperOpenTimesCount > 0
                    ).disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .padding(.leading, 10).padding(.trailing, 10)
                }
            }
            .onChange(of: selectedItems) { oldval, newval in
                Task {
                    withAnimation(.linear(duration: 0.35)) {
                        cropperOpenTimesCount += 1
                    }
                    if oldval.count == 0 && displayImages.count > 0 {
                        displayImages.removeAll()
                        handlePositions.removeAll()
                    }
                    for selectedItemOrder in 0..<selectedItems.count {
                        if let data = try? await selectedItems[selectedItemOrder].loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            displayImages.append(image)
                        }
                    }
                    selectedItems = []
                }
            }
    }
}

// source:
// https://gist.github.com/schickling/b5d86cb070130f80bb40?permalink_comment_id=2894406#gistcomment-2894406
extension UIImage {
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != UIImage.Orientation.up else {
            return self.copy() as? UIImage
        }
        
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        guard let newCGImage = ctx.makeImage() else { return nil }
        return UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
    }
}

func cropImage(_ image: UIImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> UIImage? {
    let rectToCrop = CGRect(x: x, y: y, width: width, height: height)
    let rect = CGRect(x: rectToCrop.origin.x, y: rectToCrop.origin.y, width: rectToCrop.width, height: rectToCrop.height)

    guard let cropped = image.fixedOrientation()?.cgImage?.cropping(to: rect) else {
        return nil
    }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
}

func combineImagesVertically(images: [UIImage]) -> UIImage? {
    guard !images.isEmpty else { return nil }
    let totalHeight = images.reduce(0) { $0 + $1.size.height }
    let maxWidth = images.max { $0.size.width < $1.size.width }?.size.width ?? 0
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = images[0].scale
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxWidth, height: totalHeight), format: format)
    
    return renderer.image { ctx in
        var yOffset: CGFloat = 0
        for image in images {
            image.draw(at: CGPoint(x: 0, y: yOffset))
            yOffset += image.size.height
        }
    }
}

func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        completion(nil)
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error loading image: \(error.localizedDescription)")
            completion(nil)
            return
        }

        guard let data = data, let image = UIImage(data: data) else {
            print("Failed to decode image data")
            completion(nil)
            return
        }

        DispatchQueue.main.async {
            completion(image)
        }
    }.resume()
}

func savePhoto(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
    class CallbackWrapper: NSObject {
        let completion: (Bool, Error?) -> Void

        init(completion: @escaping (Bool, Error?) -> Void) {
            self.completion = completion
        }

        @objc func completionHandler(image: UIImage, error: Error?, contextInfo: UnsafeMutableRawPointer) {
            completion(error == nil, error)
        }
    }

    let wrapper = CallbackWrapper(completion: completion)
    UIImageWriteToSavedPhotosAlbum(image, wrapper, #selector(CallbackWrapper.completionHandler(image:error:contextInfo:)), nil)
}

struct SaveButton: View {
    @Binding var displayImages: [UIImage]
    @Binding var handlePositions: [Int: CropHandlePositions]
    @Binding var cropperOpenTimesCount: Int
    @State private var isSavingInProgress: Bool = false
    
    func cropAll() -> [UIImage] {
        var allCroppedPhotos: [UIImage] = []
        for photoIdx in displayImages.indices.reversed() {

            guard let photoCropPositions = handlePositions[handlePositions.count-1-photoIdx] else {
                return allCroppedPhotos
            }
            let photo = displayImages[displayImages.count-1-photoIdx]
            
            let pictureMiniatureHeight = photoCropPositions.bottom._max - photoCropPositions.top._min
            let ratioMiniToReal = photo.size.height / pictureMiniatureHeight
            let pictureMiniatureCropFromTop = photoCropPositions.top.current - photoCropPositions.top._min
            let remaningMiniatureHeight = pictureMiniatureHeight - pictureMiniatureCropFromTop
            let pictureMiniatureCropFromBottom = photoCropPositions.bottom._max - photoCropPositions.bottom.current
            let cropFromBottom = pictureMiniatureCropFromBottom * ratioMiniToReal
            let startCroppintAt = pictureMiniatureCropFromTop * ratioMiniToReal
            let remainingHeight = remaningMiniatureHeight * ratioMiniToReal - cropFromBottom
            if let imageCropped = cropImage(photo,
                    x: 0,
                    y: startCroppintAt,
                    width: photo.size.width,
                    height: remainingHeight
            ) {
                allCroppedPhotos.append(imageCropped)
            }
        }
        return allCroppedPhotos
    }
    
    func cropAllImagesStitchAndSaveOne() {
        isSavingInProgress = true
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return
        }
        
        let LoadingNotificationView = AlertAppleMusic17View(icon: .spinnerSmall)
        let SuccessNotificationView = AlertAppleMusic17View(title: "Added to photos", icon: .done)
        let ErrorNotificationView = AlertAppleMusic17View(title: "Error occured", icon: .error)
        SuccessNotificationView.haptic = .success
        ErrorNotificationView.haptic = .error
        
        LoadingNotificationView.present(on: keyWindow)


        let allCroppedPhotos: [UIImage] = cropAll()
        guard let allImagesCombined = combineImagesVertically(images: allCroppedPhotos) else {
            return
        }

        savePhoto(allImagesCombined) { success, error in
            LoadingNotificationView.dismiss()
            isSavingInProgress = false
            if success {
                SuccessNotificationView.present(on: keyWindow)
            } else {
                ErrorNotificationView.present(on: keyWindow)
            }
        }
    }
    
    var body: some View {
        if cropperOpenTimesCount > 0 {
            ButtonStyled("arrow.down.square", "Save", _is: .secondary, isShrinkened: cropperOpenTimesCount == 0) {
                cropAllImagesStitchAndSaveOne()
            }.padding(.trailing, 10).disabled(isSavingInProgress).transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}


struct ContentView: View {
    @State private var displayImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var handlePositions: [Int: CropHandlePositions] = [:]
    @State private var cropperOpenTimesCount: Int = 0

    var body: some View {
        if cropperOpenTimesCount == 0 {
            VStack {
                VStack {
                    Image(uiImage: UIImage(named: "logo")!).resizable().frame(width: 22.42, height: 24.18)
                    Text("sitchy")
                }.padding(.top, 50)
                Text("Crop and stitch screenshots vertically").font(.system(size: 21)).padding(.top, 52)
                Spacer()
                Image(uiImage: UIImage(named: "welcome-screen-illustration")!).padding(.bottom, 10)
            }
            .transition(.move(edge: .leading))
        }
        VStack {
            ImageScrollView(cropperOpenTimesCount: $cropperOpenTimesCount, $displayImages, $handlePositions)
            HStack(spacing: 0){
                PhotosPickerView(cropperOpenTimesCount: $cropperOpenTimesCount, $selectedItems, $displayImages, $handlePositions)
                SaveButton(displayImages: $displayImages, handlePositions: $handlePositions, cropperOpenTimesCount: $cropperOpenTimesCount)
            }
        }
    }
}

#Preview {
    ContentView()
}
