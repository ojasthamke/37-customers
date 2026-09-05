String sanitizeCustomerName(String? name, {String? customerCode}) {
  if (name == null || name.trim().isEmpty) return 'Guest';
  
  final trimmed = name.trim();
  
  // Prevent customer code from leaking as display name
  if (customerCode != null && trimmed.toLowerCase() == customerCode.trim().toLowerCase()) {
    return 'Customer';
  }
  
  final codePattern = RegExp(r'^[A-Z]{2,4}\d{2,6}$', caseSensitive: false);
  if (codePattern.hasMatch(trimmed)) {
    return 'Customer';
  }
  
  final parts = trimmed.split(RegExp(r'\s+'));
  
  if (parts.length > 1) {
    final lastWord = parts.last;
    
    // List of common customer suffix codes to hide (R, L, M, U, D, LD, LR, etc.)
    // We check if the last word is 1 or 2 characters (case insensitive check)
    if (lastWord.length <= 2) {
      return parts.sublist(0, parts.length - 1).join(' ');
    }
  }
  
  return trimmed;
}

String getProductImage(String productName, String? imagePath) {
  if (imagePath != null && imagePath.trim().isNotEmpty) {
    final trimmed = imagePath.trim().replaceAll('"', '').replaceAll("'", '');
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Sanitize: replace any internal whitespace with %20
      return trimmed.replaceAll(' ', '%20');
    }
    // Handle Supabase Storage relative paths uploaded by admin / OrderKart
    if (trimmed.startsWith('product-images/')) {
      return 'https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/$trimmed';
    }
    if (trimmed.startsWith('product_') && (trimmed.endsWith('.jpg') || trimmed.endsWith('.png') || trimmed.endsWith('.jpeg') || trimmed.endsWith('.webp'))) {
      return 'https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/product-images/$trimmed';
    }
  }

  final n = productName.toLowerCase().trim();

  // ── 1. Leafy Greens & Fresh Herbs ──────────────────────────────────────────
  if (n.contains('palak') || n.contains('spinach') || n.contains('पालक')) {
    return 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=600&q=80'; // Fresh Spinach
  }
  if (n.contains('methi') || n.contains('fenugreek') || n.contains('मेथी')) {
    return 'https://images.unsplash.com/photo-1628773822503-930a84594c7b?auto=format&fit=crop&w=600&q=80'; // Fenugreek / Methi
  }
  if (n.contains('coriander') || n.contains('dhania') || n.contains('dhaniya') || n.contains('kothimbir') || n.contains('कोथिंबीर') || n.contains('sambar') || n.contains('सांबर')) {
    return 'https://images.unsplash.com/photo-1588879460618-9249e7d947d1?auto=format&fit=crop&w=600&q=80'; // Fresh Coriander
  }
  if (n.contains('pudina') || n.contains('mint') || n.contains('पुदिना')) {
    return 'https://images.unsplash.com/photo-1628556270448-4d4e4148e1b1?auto=format&fit=crop&w=600&q=80'; // Fresh Mint
  }
  if (n.contains('shepu') || n.contains('dill') || n.contains('शेपू')) {
    return 'https://images.unsplash.com/photo-1596097635121-14b63b7a0c19?auto=format&fit=crop&w=600&q=80'; // Fresh Dill
  }
  if (n.contains('curry') || n.contains('kadi patta') || n.contains('कढीपत्ता')) {
    return 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80'; // Curry Leaves
  }
  if (n.contains('spring onion') || n.contains('kanda paat') || n.contains('कांद्याची पात')) {
    return 'https://images.unsplash.com/photo-1580201092675-a0a6a6cafbb1?auto=format&fit=crop&w=600&q=80'; // Fresh Spring Onions
  }

  // ── 2. Daily Vegetables (Bilingual Marathi / Hindi / English) ─────────────
  if (n.contains('potato') || n.contains('aloo') || n.contains('aalu') || n.contains('batata') || n.contains('बटाटा') || n.contains('आलु') || n.contains('आलू')) {
    return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80'; // Fresh Potatoes
  }
  if (n.contains('tomato') || n.contains('tamatar') || n.contains('टोमॅटो') || n.contains('टमाटर')) {
    return 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80'; // Ripe Fresh Tomatoes
  }
  if (n.contains('onion') || n.contains('pyaz') || n.contains('pyaj') || n.contains('kanda') || n.contains('कांदा')) {
    return 'https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=600&q=80'; // Red Onions
  }
  if (n.contains('bhendi') || n.contains('bhindi') || n.contains('lady finger') || n.contains('ladyfinger') || n.contains('okra') || n.contains('भेंडी')) {
    return 'https://images.unsplash.com/photo-1425543103986-22abb7d7e8d2?auto=format&fit=crop&w=600&q=80'; // Fresh Green Okra / Lady Finger
  }
  if (n.contains('vange') || n.contains('vangi') || n.contains('brinjal') || n.contains('eggplant') || n.contains('baingan') || n.contains('वांग') || n.contains('वांगी') || n.contains('bharit')) {
    return 'https://images.unsplash.com/photo-1628773822503-930a84594c7b?auto=format&fit=crop&w=600&q=80'; // Purple Brinjal / Eggplant
  }
  if (n.contains('gajar') || n.contains('carrot') || n.contains('गाजर')) {
    return 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?auto=format&fit=crop&w=600&q=80'; // Fresh Carrots
  }
  if (n.contains('limbu') || n.contains('lemon') || n.contains('nimbu') || n.contains('लिंबू') || n.contains('नींबू')) {
    return 'https://images.unsplash.com/photo-1533082603893-6c7003a3d5e2?auto=format&fit=crop&w=600&q=80'; // Juicy Lemons
  }
  if (n.contains('mirchi') || n.contains('chilli') || n.contains('chili') || n.contains('मिरची') || n.contains('shimla') || n.contains('capsicum') || n.contains('ढोबळी')) {
    return 'https://images.unsplash.com/photo-1564687679808-16ec221b6d19?auto=format&fit=crop&w=600&q=80'; // Green Chillies
  }
  if (n.contains('ginger') || n.contains('adrak') || n.contains('aadrak') || n.contains('ale') || n.contains('आले') || n.contains('अद्रक') || n.contains('आंद्रक')) {
    return 'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?auto=format&fit=crop&w=600&q=80'; // Fresh Ginger Root
  }
  if (n.contains('garlic') || n.contains('lasun') || n.contains('lahsun') || n.contains('लसूण') || n.contains('लसुन') || n.contains('लहसुन')) {
    return 'https://images.unsplash.com/photo-1589618474797-59f61b0c0347?auto=format&fit=crop&w=600&q=80'; // Fresh Garlic Bulbs
  }
  if (n.contains('kakdi') || n.contains('cucumber') || n.contains('kheera') || n.contains('काकडी') || n.contains('खीरा')) {
    return 'https://images.unsplash.com/photo-1604977042946-1eecc30f269e?auto=format&fit=crop&w=600&q=80'; // Fresh Crisp Cucumber
  }
  if (n.contains('karle') || n.contains('karela') || n.contains('bitter gourd') || n.contains('कारले') || n.contains('कार्ले')) {
    return 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80'; // Bitter Gourd
  }
  if (n.contains('dodhke') || n.contains('dodka') || n.contains('turai') || n.contains('ridge gourd') || n.contains('दोडके') || n.contains('दोडका')) {
    return 'https://images.unsplash.com/photo-1590165482129-1b8b27698980?auto=format&fit=crop&w=600&q=80'; // Ridge Gourd
  }
  if (n.contains('lauki') || n.contains('dudhi') || n.contains('bottle gourd') || n.contains('लौकी') || n.contains('दुधी')) {
    return 'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?auto=format&fit=crop&w=600&q=80'; // Bottle Gourd / Lauki
  }
  if (n.contains('fulgobi') || n.contains('flower') || n.contains('phool') || n.contains('cauliflower') || n.contains('फुलगोबी') || n.contains('फूलगोभी')) {
    return 'https://images.unsplash.com/photo-1568584711075-3d021a7c3ca3?auto=format&fit=crop&w=600&q=80'; // Cauliflower / Fulgobi
  }
  if (n.contains('patta') || n.contains('kobi') || n.contains('cabbage') || n.contains('कोबी') || n.contains('पत्ता')) {
    return 'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?auto=format&fit=crop&w=600&q=80'; // Fresh Green Cabbage
  }
  if (n.contains('shevga') || n.contains('drumstick') || n.contains('शेवगा')) {
    return 'https://images.unsplash.com/photo-1628773822503-930a84594c7b?auto=format&fit=crop&w=600&q=80'; // Drumstick / Shevga
  }
  if (n.contains('shenga') || n.contains('chavri') || n.contains('chawli') || n.contains('gavar') || n.contains('beans') || n.contains('farasbi') || n.contains('शेंगा') || n.contains('गवार') || n.contains('वाला')) {
    return 'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=600&q=80'; // Fresh Green Beans / Gavar
  }
  if (n.contains('beet') || n.contains('beetroot') || n.contains('बीट')) {
    return 'https://images.unsplash.com/photo-1528793444498-8422784d1a1b?auto=format&fit=crop&w=600&q=80'; // Red Beetroot
  }
  if (n.contains('dhemsha') || n.contains('tinda') || n.contains('ढेमसे')) {
    return 'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?auto=format&fit=crop&w=600&q=80'; // Round Gourd / Dhemsha
  }
  if (n.contains('matar') || n.contains('vatana') || n.contains('peas') || n.contains('मटार') || n.contains('वाटाणा')) {
    return 'https://images.unsplash.com/photo-1587735243615-c03f25aaff15?auto=format&fit=crop&w=600&q=80'; // Green Sweet Peas
  }
  if (n.contains('mula') || n.contains('mooli') || n.contains('radish') || n.contains('मुळा')) {
    return 'https://images.unsplash.com/photo-1593105544559-ecb03bf76f82?auto=format&fit=crop&w=600&q=80'; // White Radish / Mula
  }
  if (n.contains('bhopla') || n.contains('pumpkin') || n.contains('kaddu') || n.contains('भोपळा')) {
    return 'https://images.unsplash.com/photo-1570586437263-ab629fccc818?auto=format&fit=crop&w=600&q=80'; // Pumpkin
  }
  if (n.contains('corn') || n.contains('makka') || n.contains('bhutta') || n.contains('मका')) {
    return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&w=600&q=80'; // Sweet Corn
  }

  // ── 3. Fresh Fruits ───────────────────────────────────────────────────────
  if (n.contains('apple') || n.contains('seb') || n.contains('safarchand') || n.contains('सफरचंद')) {
    return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80'; // Red Apples
  }
  if (n.contains('banana') || n.contains('kela') || n.contains('केळी')) {
    return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80'; // Ripe Bananas
  }
  if (n.contains('orange') || n.contains('santara') || n.contains('संत्री') || n.contains('mosambi') || n.contains('मोसंबी')) {
    return 'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=600&q=80'; // Fresh Oranges
  }
  if (n.contains('grape') || n.contains('draksha') || n.contains('angoor') || n.contains('द्राक्षे')) {
    return 'https://images.unsplash.com/photo-1537640538966-79f369143f8f?auto=format&fit=crop&w=600&q=80'; // Fresh Grapes
  }
  if (n.contains('watermelon') || n.contains('tarbuj') || n.contains('kalingad') || n.contains('कलिंगड')) {
    return 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?auto=format&fit=crop&w=600&q=80'; // Watermelon
  }
  if (n.contains('papaya') || n.contains('papai') || n.contains('पपई')) {
    return 'https://images.unsplash.com/photo-1617112848923-cc2234396a8d?auto=format&fit=crop&w=600&q=80'; // Papaya
  }
  if (n.contains('mango') || n.contains('aam') || n.contains('amba') || n.contains('आंबा')) {
    return 'https://images.unsplash.com/photo-1553279768-865429fa0078?auto=format&fit=crop&w=600&q=80'; // Mango
  }
  if (n.contains('pomegranate') || n.contains('anar') || n.contains('dalimb') || n.contains('डाळिंब')) {
    return 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80'; // Pomegranate
  }
  if (n.contains('guava') || n.contains('peru') || n.contains('amrood') || n.contains('पेरू')) {
    return 'https://images.unsplash.com/photo-1536511135899-70a006c9b360?auto=format&fit=crop&w=600&q=80'; // Fresh Guava
  }
  if (n.contains('chikoo') || n.contains('chiku') || n.contains('चीकू')) {
    return 'https://images.unsplash.com/photo-1596547609652-9cf5d8d76921?auto=format&fit=crop&w=600&q=80'; // Chikoo / Sapodilla
  }
  if (n.contains('pineapple') || n.contains('ananas') || n.contains('अननस')) {
    return 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?auto=format&fit=crop&w=600&q=80'; // Pineapple
  }
  if (n.contains('coconut') || n.contains('naral') || n.contains('नारळ') || n.contains('शहाळे')) {
    return 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=600&q=80'; // Coconut
  }

  // ── 4. Dairy, Staples & Groceries ─────────────────────────────────────────
  if (n.contains('milk') || n.contains('doodh') || n.contains('दूध')) {
    return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80'; // Fresh Milk
  }
  if (n.contains('paneer') || n.contains('पनीर')) {
    return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80'; // Fresh Paneer
  }
  if (n.contains('curd') || n.contains('dahi') || n.contains('दही') || n.contains('taak') || n.contains('ताक')) {
    return 'https://images.unsplash.com/photo-1571212515416-fef01fc43637?auto=format&fit=crop&w=600&q=80'; // Fresh Curd
  }
  if (n.contains('ghee') || n.contains('तूप')) {
    return 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=600&q=80'; // Pure Ghee
  }
  if (n.contains('oil') || n.contains('tel') || n.contains('तेल')) {
    return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=600&q=80'; // Cooking Oil
  }
  if (n.contains('egg') || n.contains('ande') || n.contains('अंडी')) {
    return 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=600&q=80'; // Farm Fresh Eggs
  }
  if (n.contains('rice') || n.contains('tandul') || n.contains('chawal') || n.contains('तांदूळ')) {
    return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80'; // Rice Grains
  }
  if (n.contains('wheat') || n.contains('atta') || n.contains('gahu') || n.contains('आटा') || n.contains('गहू')) {
    return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80'; // Wheat Flour
  }
  if (n.contains('poha') || n.contains('pohe') || n.contains('पोहे')) {
    return 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=600&q=80'; // Flattened Rice / Poha
  }
  if (n.contains('dal') || n.contains('toor') || n.contains('tur') || n.contains('moong') || n.contains('डाळ')) {
    return 'https://images.unsplash.com/photo-1585994192704-5e1fe97f482a?auto=format&fit=crop&w=600&q=80'; // Pulses & Lentils
  }
  if (n.contains('tea') || n.contains('chaha') || n.contains('चहा') || n.contains('चाय')) {
    return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80'; // Premium Tea
  }

  // Canonical Fresh Farm Produce Fallback
  return 'https://images.unsplash.com/photo-1610348725531-843dff563e2c?auto=format&fit=crop&w=600&q=80';
}
