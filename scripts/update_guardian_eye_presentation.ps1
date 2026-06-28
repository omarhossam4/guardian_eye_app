param(
    [string]$InputPath = "C:\Users\Omar Hossam\Downloads\vercel last\guardian_eye_app\Blue Black and White Modern Medical Science Presentation.pptx",
    [string]$OutputPath = "C:\Users\Omar Hossam\Downloads\vercel last\guardian_eye_app\Guardian Eye AI Presentation.pptx"
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

function Escape-XmlText {
    param([string]$Text)

    if ($null -eq $Text) { return '' }

    return [System.Security.SecurityElement]::Escape($Text)
}

function Update-SlideText {
    param(
        [string]$Xml,
        [string[]]$Values
    )

    $matches = [regex]::Matches($Xml, '<a:t>.*?</a:t>', 'Singleline')
    $result = $Xml

    for ($i = $matches.Count - 1; $i -ge 0; $i--) {
        $value = if ($i -lt $Values.Count) { $Values[$i] } else { '' }
        $replacement = "<a:t>$(Escape-XmlText $value)</a:t>"
        $result = $result.Remove($matches[$i].Index, $matches[$i].Length).Insert($matches[$i].Index, $replacement)
    }

    return $result
}

$slides = @{
    1 = @(
        'Guardian',
        'Eye',
        'AI Assistant',
        'for Visually Impaired People'
    )
    2 = @(
        'Introduction to ',
        'Guardian',
        'Eye Project',
        '24/7',
        'Vision assistance',
        'Guardian Eye is an AI-powered assistant designed to improve independence and safety for visually impaired users. It combines computer vision, text understanding, speech interaction, and mobile guidance in one accessible workflow.',
        'AI-powered navigation and scene understanding',
        'The project helps users understand their surroundings, read printed text, ask questions about objects, and receive spoken feedback in real time. The goal is to turn a smartphone into a practical daily assistant for movement, reading, and decision support.',
        'AI ACCESS'
    )
    3 = @(
        'Problem',
        'Defin',
        'ition',
        'Guardian Eye',
        'Visually impaired people often face barriers when identifying objects, reading labels, navigating unfamiliar places, and reacting quickly to obstacles. Daily tasks that sighted users perform in seconds may require assistance, extra time, or risky guesswork.',
        'Existing tools usually solve one task only, such as reading text or detecting objects, but they do not provide a complete assistive experience. Our project addresses this gap by combining perception, reasoning, and voice interaction in a single mobile system.'
    )
    4 = @(
        'System Architecture',
        'of Guar',
        'dian Eye',
        'Guardian Eye',
        'Mobile Camera Input - captures the live scene continuously',
        'Preprocessing Layer - frames and images are prepared for analysis',
        'YOLO Detection - recognizes objects, hazards, and scene elements',
        'OCR + LLM - extracts text and explains it in useful language',
        'Speech Modules - converts voice commands to text and answers back',
        'Mobile App Output - delivers alerts, descriptions, and guidance',
        'The architecture follows a multimodal pipeline where visual data and voice commands are processed by specialized AI modules, then fused into simple spoken feedback that the user can act on immediately.'
    )
    5 = @(
        'AI',
        ' Mod',
        'els: YOLO',
        'Guardian Eye',
        'Real-time object detection for doors, chairs, cars, stairs, and people',
        'Obstacle awareness to warn users about hazards in front of them',
        'Fast inference suitable for mobile-friendly assistive scenarios',
        'Spatial context by estimating where objects appear in the frame',
        'High-value alerts focused on immediate safety and navigation',
        'YOLO is the perception core of the system. It gives the application quick awareness of surrounding objects so the user can receive immediate spoken notifications about what is nearby and what may block the path.',
        'Detection tuned for practical daily objects',
        'YOLO improves independence by turning camera frames into fast environmental awareness, especially in indoor spaces, sidewalks, entrances, and crowded settings.',
        '90%',
        'Real-time response',
        'OBJECTS'
    )
    6 = @(
        'OCR +',
        ' LLM',
        ' for Reading',
        'and Understanding',
        'Guardian Eye',
        'OCR extracts printed text from labels, signs, documents, and medicine boxes',
        'LLM summarizes complex content into short, useful spoken answers',
        'Text can be translated, explained, or converted into task-oriented guidance',
        'Context-aware responses help the user understand meaning, not only raw text',
        'Multi-step reading support for menus, instructions, and forms',
        'This module goes beyond text recognition. After OCR reads the visible content, the language model can explain what it means, answer follow-up questions, and present the result in a way that is easier to understand through audio.',
        'From text extraction to smart explanation'
    )
    7 = @(
        'Speech',
        ' Interac',
        'tion & Au',
        'dio Output',
        'Guardian Eye',
        'Speech recognition captures user commands without touching the screen',
        'Voice prompts make the app easier to use while walking or multitasking',
        'Text-to-speech returns descriptions, warnings, and answers clearly',
        'Hands-free interaction improves accessibility and comfort',
        'Natural dialogue allows users to ask follow-up questions in real time',
        'Speech interaction is essential for accessibility because it removes dependence on visual menus. Users can ask the app what is ahead, request text reading, and receive immediate verbal feedback tailored to the scene.',
        'Designed for smooth two-way communication'
    )
    8 = @(
        'Challen',
        'ges',
        ' in',
        ' AI',
        'for Accessibility',
        'Guardian Eye',
        'Lighting changes, blur, and camera angle can reduce detection quality in real environments.',
        'Text recognition becomes harder on curved surfaces, small labels, or low-contrast packaging.',
        'Speech recognition may struggle in noisy streets or crowded public places.',
        'Latency must stay low so spoken guidance remains helpful and safe.',
        'Model accuracy and battery efficiency must be balanced for mobile deployment.',
        'Building assistive AI means solving more than accuracy. The system must also remain fast, understandable, and reliable enough to support real users during everyday movement and reading tasks.',
        'User trust depends on consistency, clarity, and low delay.'
    )
    9 = @(
        'AI Demo',
        'Scene Walkthrough',
        'Guardian Eye',
        '1. User points the camera toward the environment',
        '2. YOLO detects nearby objects and hazards',
        '3. OCR reads visible text such as signs or labels',
        '4. LLM explains the result in simple language',
        '5. Speech output tells the user what to do next',
        '6. User can ask follow-up questions by voice',
        'The demo shows how the AI pipeline works as one experience instead of separate features. From a single camera view, the app detects objects, reads text, interprets meaning, and answers through audio in a few seconds.',
        'A complete assistive AI flow from vision to action'
    )
    10 = @(
        'Software',
        ' Development',
        'Guardian Eye',
        'Mobile App Frontend',
        'Flutter / accessible UI design',
        'Backend and AI Integration',
        'Model serving and API communication',
        'Testing and Iteration',
        'Usability feedback with assistive scenarios'
    )
    11 = @(
        'App Demo',
        'Screens',
        'and Results',
        'Overview',
        'Feature',
        'What the user experiences',
        'Value',
        '1',
        'Object detection',
        'Real-time spoken alerts about obstacles and nearby items',
        '2',
        'Text reading',
        'Reads signs, labels, and short documents aloud',
        '3',
        'Question answering',
        'Explains the scene or extracted text using natural language',
        '4',
        'Voice control',
        'Lets the user interact without needing visual navigation',
        '5',
        'Safety support',
        'Improves confidence during movement and daily tasks'
    )
    12 = @(
        'Th',
        'e ',
        'Impact',
        'Today',
        '',
        'of Guar',
        'dian Eye',
        'Guardian Eye',
        'The project is designed to improve independence, reduce reliance on constant assistance, and make everyday information more accessible for visually impaired users.',
        'Supports safer navigation in unfamiliar places',
        'Improves access to printed information and signs',
        'Creates a more natural, voice-first assistive experience',
        'Safety',
        'Independence',
        'AI & Access'
    )
    13 = @(
        'Futu',
        're Work',
        ' in',
        ' ',
        'Guar',
        'dian Eye',
        'Guardian Eye',
        'Future improvements include better distance estimation, offline inference for faster response, multilingual voice support, and personalized alerts based on user preference and environment.',
        'Another next step is broader testing with real users to refine accuracy, phrasing, and trust. The strongest assistive systems are built not only with AI models, but with repeated feedback from the people who depend on them.'
    )
    14 = @(
        'Con',
        'clus',
        'ion',
        'Guardian Eye',
        'Guardian Eye combines computer vision, language understanding, and speech interaction into one assistive platform.',
        'The project focuses on practical tasks such as detecting objects, reading text, and guiding the user through spoken feedback.',
        'By merging multiple AI capabilities in a simple mobile experience, the system can make daily life safer, faster, and more independent for visually impaired people.'
    )
    15 = @(
        'Thank ',
        'You',
        'Guardian Eye',
        'AI for visually impaired people should be accurate, simple, and human-centered. Thank you for your time and attention.',
        '+20 000 000 0000',
        'guardianeye.ai',
        '@guardianeye',
        'AI Accessibility Project, Cairo',
        'Egypt'
    )
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

Copy-Item -LiteralPath $InputPath -Destination $OutputPath -Force

$fileStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)

try {
    $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Update)

    foreach ($slideNumber in $slides.Keys | Sort-Object) {
        $entryPath = "ppt/slides/slide$slideNumber.xml"
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $entryPath }

        if (-not $entry) {
            continue
        }

        $reader = New-Object System.IO.StreamReader($entry.Open())
        $xml = $reader.ReadToEnd()
        $reader.Close()

        $updatedXml = Update-SlideText -Xml $xml -Values $slides[$slideNumber]
        $entry.Delete()
        $newEntry = $zip.CreateEntry($entryPath)

        $writer = New-Object System.IO.StreamWriter($newEntry.Open())
        $writer.Write($updatedXml)
        $writer.Flush()
        $writer.Close()
    }

    $coreEntry = $zip.Entries | Where-Object { $_.FullName -eq 'docProps/core.xml' }
    if ($coreEntry) {
        $reader = New-Object System.IO.StreamReader($coreEntry.Open())
        $coreXml = $reader.ReadToEnd()
        $reader.Close()

        $coreXml = [regex]::Replace($coreXml, '<dc:title>.*?</dc:title>', '<dc:title>Guardian Eye AI Presentation</dc:title>')
        $coreEntry.Delete()
        $newCoreEntry = $zip.CreateEntry('docProps/core.xml')
        $writer = New-Object System.IO.StreamWriter($newCoreEntry.Open())
        $writer.Write($coreXml)
        $writer.Flush()
        $writer.Close()
    }

    $zip.Dispose()
}
finally {
    $fileStream.Dispose()
}

Write-Output "Updated presentation saved to: $OutputPath"
