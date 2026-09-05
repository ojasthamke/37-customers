import 'package:flutter/material.dart';

class PolicyItem {
  final String id;
  final String title;
  final String marathiTitle;
  final String summary;
  final IconData icon;
  final String effectiveDate;
  final String lastUpdated;
  final List<PolicySection> sections;

  const PolicyItem({
    required this.id,
    required this.title,
    required this.marathiTitle,
    required this.summary,
    required this.icon,
    required this.effectiveDate,
    required this.lastUpdated,
    required this.sections,
  });
}

class PolicySection {
  final String heading;
  final String content;
  final List<String>? bulletPoints;

  const PolicySection({
    required this.heading,
    required this.content,
    this.bulletPoints,
  });
}

class OrderKartPolicies {
  static const String storeName = 'OrderKart';
  static const String legalEntity = 'OrderKart Fresh Foods & Essentials';
  static const String supportPhone = '+91 90211 07009';
  static const String supportEmail = 'supportorderkart@gmail.com';
  static const String repositoryUrl = 'https://github.com/ojasthamke/OrderKart-main';
  static const String operatingAddress = 'Market Yard, Yavatmal, Maharashtra 445001, India';
  static const String grievanceOfficer = 'Grievance Redressal Officer, OrderKart Compliance';
  static const String effectiveDate = '1 August 2026';
  static const String lastUpdatedDate = '31 August 2026';

  static List<PolicyItem> getAllPolicies() {
    return [
      privacyPolicy,
      termsAndConditions,
      refundAndCancellationPolicy,
      deliveryPolicy,
      accountDeletionPolicy,
      pricingPolicy,
      grievancePolicy,
    ];
  }

  // 1. Privacy Policy
  static const PolicyItem privacyPolicy = PolicyItem(
    id: 'privacy_policy',
    title: 'Privacy Policy',
    marathiTitle: 'गोपनीयता धोरण',
    summary: 'How OrderKart collects, protects, uses, and respects your personal & order data.',
    icon: Icons.privacy_tip_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Overview & Commitment',
        content: 'OrderKart ("we", "us", "our") values your trust and is dedicated to protecting your privacy. This Privacy Policy governs the manner in which OrderKart collects, uses, maintains, and discloses information collected from customers ("you", "your") using the OrderKart mobile application. We comply with applicable Indian data protection laws, including the Information Technology Act 2000, IT Rules 2021, and Digital Personal Data Protection (DPDP) Act 2023.',
      ),
      PolicySection(
        heading: '2. Information We Collect',
        content: 'To facilitate seamless doorstep delivery of fresh vegetables, fruits, and groceries, we collect the following limited information:',
        bulletPoints: [
          'Personal Identifiers: Full name, primary mobile number, alternate contact number, email address (when using Google Sign-In), and unique Customer Member Code assigned by the store.',
          'Delivery Details: Delivery address, house/flat number, road/street name, sub-road, and registered delivery area name.',
          'Order & Transaction Records: Order history, items purchased, quantities, pricing snapshots, order timestamps, and delivery schedules.',
          'Device & App Information: Firebase Cloud Messaging (FCM) device registration tokens (for delivery and order update notifications) and basic network connectivity status (WiFi/Cellular/Offline).',
          'Security Tokens: Session authentication tokens and Google OAuth identity tokens stored securely on your device using encrypted storage.',
        ],
      ),
      PolicySection(
        heading: '3. What We DO NOT Collect (Permissions Clarification)',
        content: 'To safeguard your privacy, our app strictly limits permissions. We DO NOT collect, request, or access:',
        bulletPoints: [
          'No Background GPS or Precise Device Location (Addresses are selected via store-defined area routes).',
          'No Camera, Photos, Gallery, or Media Storage access.',
          'No Microphone, Audio, or Bluetooth access.',
          'No Device Contacts, Phonebooks, or Call logs.',
          'No Financial Bank Account numbers, Debit/Credit Card details, or CVVs (All payments are settled upon delivery via Cash or QR/UPI).',
        ],
      ),
      PolicySection(
        heading: '4. How We Use Your Information',
        content: 'We use the collected information exclusively for lawful business and fulfillment operations:',
        bulletPoints: [
          'Processing, assembling, and delivering your scheduled and quick orders to your doorstep.',
          'Sending timely, critical push notifications regarding order confirmation, dispatch, delivery arrival, and store schedule alerts.',
          'Authenticating your account via secure customer code and password/PIN.',
          'Enforcing security safeguards against brute-force attacks via temporary lockout mechanisms.',
          'Providing direct customer support via WhatsApp and phone.',
        ],
      ),
      PolicySection(
        heading: '5. Third-Party Service Providers',
        content: 'We partner with trusted, industry-standard technology providers who process data under strict confidentiality obligations:',
        bulletPoints: [
          'Supabase Inc. (Backend Cloud Database & Authentication): Data stored securely in enterprise-grade PostgreSQL with TLS 1.3 transit encryption and AES-256 rest encryption.',
          'Google Identity & Firebase Services: Used securely for Google Sign-In authentication and Firebase Cloud Messaging (FCM) push notifications.',
          'Google Fonts: Provides clean typography rendered inside the mobile application.',
        ],
      ),
      PolicySection(
        heading: '6. Data Security & Technical Diagnostics',
        content: 'All network communications are secured with HTTPS / TLS 1.3 encryption. Your authentication tokens are stored locally using hardware-backed secure storage. When you use the app, cloud servers (Supabase & Google Cloud) automatically log standard technical diagnostic information (including IP addresses, API request timestamps, and performance metrics) strictly for security protection, network integrity, and uptime monitoring.',
      ),
      PolicySection(
        heading: '7. Data Retention & Deletion Rights',
        content: 'You retain complete ownership over your data. You may request permanent deletion of your online app account at any time directly through the app (Profile > Delete Account) or via our web request portal. Upon confirmation, your credentials, auth tokens, and session references are permanently purged from cloud databases. In accordance with applicable Indian accounting and tax regulations, completed transaction receipts and store ledger entries are retained in the shop management system.',
      ),
      PolicySection(
        heading: '8. Changes to this Policy',
        content: 'We may update this Privacy Policy periodically. Any modifications will be updated directly within this page along with a revised "Last Updated" date. Continued use of the app constitutes acceptance of the revised terms.',
      ),
    ],
  );

  // 2. Terms & Conditions
  static const PolicyItem termsAndConditions = PolicyItem(
    id: 'terms_and_conditions',
    title: 'Terms & Conditions',
    marathiTitle: 'नियम व अटी',
    summary: 'General terms of service, account usage rules, and mutual store agreements.',
    icon: Icons.description_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Introduction & Acceptance',
        content: 'Welcome to OrderKart. By installing, browsing, or placing an order through the OrderKart mobile application, you agree to be bound by these Terms & Conditions. If you do not agree with any part of these terms, please do not use our services.',
      ),
      PolicySection(
        heading: '2. Customer Account & Code Allocation',
        content: 'Customer accounts are created and assigned unique identification codes (e.g. MEM101) by OrderKart. You are responsible for maintaining the confidentiality of your credentials (PIN/Password). Any order placed through your authenticated account is deemed authorized by you.',
      ),
      PolicySection(
        heading: '3. Fresh Produce & Natural Variations',
        content: 'We deliver farm-fresh vegetables and fruits. Due to the natural perishable nature of farm produce:',
        bulletPoints: [
          'Weight Tolerance: Items sold by weight may have slight variations (+/- 2-5%) due to natural moisture evaporation during sorting and transit.',
          'Seasonal Availability: Availability is subject to daily morning wholesale market arrivals. If an item is unavailable at fulfillment, it will be marked out-of-stock and deducted from your final bill.',
        ],
      ),
      PolicySection(
        heading: '4. Ordering & Delivery Schedules',
        content: 'Orders are accepted based on scheduled delivery days assigned to your registered area or via Quick Orders. Orders placed prior to the store cutoff time (e.g., 23:59) are scheduled for the next delivery day; orders placed after cutoff automatically roll over to the subsequent delivery day.',
      ),
      PolicySection(
        heading: '5. Payment & Settlement',
        content: 'OrderKart does not process digital debit/credit cards within the app. Payment terms are Pay on Delivery (Cash on Delivery or on-the-spot UPI QR transfer to the delivery executive). Full payment is due upon doorstep receipt of the order.',
      ),
      PolicySection(
        heading: '6. User Conduct & Abuse Prevention',
        content: 'Customers agree not to place fraudulent orders, provide false delivery addresses, or engage in abusive behavior towards delivery executives or store personnel. OrderKart reserves the right to suspend or terminate accounts engaging in fraudulent activities.',
      ),
      PolicySection(
        heading: '7. Limitation of Liability',
        content: 'To the maximum extent permitted by applicable law, OrderKart and its operating entities shall not be liable for indirect, incidental, or consequential damages resulting from delivery delays caused by force majeure events, severe weather conditions, or unforeseen agricultural market shortages.',
      ),
      PolicySection(
        heading: '8. Development Stage, Calculation & System Accuracy Disclaimer',
        content: 'OrderKart is under active development and continuous improvement to enhance user experience and service reliability. While we make all reasonable commercial efforts to ensure that all information, catalog prices, item quantities, arithmetic calculations, delivery charges, order totals, and stock availability displayed across the application are accurate and up-to-date, occasional technical glitches, software anomalies, or display errors may occur.',
        bulletPoints: [
          'Scope of Potential Discrepancies: Technical errors may occasionally result in inaccurate price representations, quantity miscalculations, rounded total discrepancies, outdated stock availability statuses, or erroneous system-generated order details.',
          'Pre-Confirmation Review: Customers are strongly advised to review their itemized cart, selected quantities, delivery addresses, and calculated order totals before placing and confirming any order.',
          'Reporting Discrepancies: If you observe an incorrect price, quantity, abnormal calculation, or system malfunction, please notify our support team promptly via WhatsApp (+91 90211 07009) or email (supportorderkart@gmail.com).',
          'Investigation & Updates: We will review reported issues in good faith and, where appropriate, rectify the system, update catalog data, or provide necessary billing adjustments. Please note that technical resolutions or system updates may require diagnostic time and cannot be guaranteed to occur instantaneously.',
          'Limitation of Liability: To the maximum extent permitted by applicable law, OrderKart, its operators, and affiliates shall not be held liable for any direct, indirect, incidental, or consequential losses, inconvenience, or damages arising solely from temporary technical errors, calculation discrepancies, inaccurate app data, or development-stage software defects. Nothing in this disclaimer shall exclude or limit any statutory consumer rights, warranties, or liabilities that cannot be lawfully excluded or limited under applicable Indian laws, nor does it diminish our Doorstep Inspection and Refund Policy for delivered physical produce.',
        ],
      ),
    ],
  );

  // 3. Refund & Cancellation Policy
  static const PolicyItem refundAndCancellationPolicy = PolicyItem(
    id: 'refund_and_cancellation',
    title: 'Refund & Cancellation Policy',
    marathiTitle: 'परतावा व ऑर्डर रद्द करण्याचे धोरण',
    summary: 'Guidelines for order cancellation, fresh produce quality returns, and billing adjustments.',
    icon: Icons.currency_exchange_rounded,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Order Cancellation by Customer',
        content: 'We understand plans change. You may cancel your scheduled order free of charge before it is packed or dispatched for delivery:',
        bulletPoints: [
          'Pre-Orders / Scheduled Delivery: You can cancel your order up until 4 hours before the scheduled morning delivery slot by contacting support via WhatsApp or Phone.',
          'Quick Orders (1-2 Hours): Because quick orders are packed and dispatched immediately, cancellations must be requested within 10 minutes of placement.',
        ],
      ),
      PolicySection(
        heading: '2. Cancellation by OrderKart',
        content: 'OrderKart reserves the right to cancel an order under unforeseen circumstances such as extreme weather, road blockages, natural disasters, or total market unavailability of key items. In such cases, you will be notified immediately.',
      ),
      PolicySection(
        heading: '3. Doorstep Inspection & Quality Guarantee',
        content: 'We maintain strict quality control. Customers are encouraged to inspect the fresh produce at the time of delivery. If any item is damaged, spoiled, or unsatisfactory:',
        bulletPoints: [
          'Immediate Return: You may hand the damaged item back to the delivery executive at the doorstep, and its value will be deducted instantly from your payable total.',
          'Post-Delivery Quality Reports: If you discover an issue within 24 hours of delivery, take a photo and message us on WhatsApp (+91 90211 07009). We will issue an instant store credit or replacement in your next order.',
        ],
      ),
      PolicySection(
        heading: '4. Refund Method & Processing Timelines',
        content: 'Refunds are issued via one of the following methods based on your preference:',
        bulletPoints: [
          'Store Ledger Credit (Instant): Added to your OrderKart customer balance immediately for deduction on your next order.',
          'Original Payment Method (UPI/Bank): Processed within 2 to 5 business days via standard banking channels.',
          'Cash Adjustment: Adjusted on the spot if payment was made via Cash on Delivery.',
        ],
      ),
    ],
  );

  // 4. Delivery Policy
  static const PolicyItem deliveryPolicy = PolicyItem(
    id: 'delivery_policy',
    title: 'Delivery Policy',
    marathiTitle: 'डिलिव्हरी धोरण',
    summary: 'Delivery timelines, area schedules, minimum order thresholds, and shipping charges.',
    icon: Icons.local_shipping_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Delivery Coverage & Area Routing',
        content: 'OrderKart operates a structured route-based delivery network across designated areas in Yavatmal, Maharashtra. Delivery days and time windows are assigned based on your registered area and road sector.',
      ),
      PolicySection(
        heading: '2. Delivery Modes & Timelines',
        content: 'We offer two convenient delivery options:',
        bulletPoints: [
          'Standard Scheduled Delivery: Farm-harvested produce delivered on your assigned area delivery days (typically morning 7:00 AM - 12:00 PM). We charge a nominal delivery fee of ₹10 to ₹15 on standard delivery.',
          'Quick Order (Order Now): Priority delivery within 1 to 2 hours of order placement during active store operating hours.',
        ],
      ),
      PolicySection(
        heading: '3. Express Handling & Quick Delivery',
        content: 'Our shipping fees are transparent and straightforward:',
        bulletPoints: [
          'Quick Delivery (1-2 Hours): Flat priority handling fee (₹20 - ₹30) applied to ensure express fulfillment.',
        ],
      ),
      PolicySection(
        heading: '4. Cutoff Times & Rollover',
        content: 'Standard orders placed before the store cutoff time (23:59 / 11:59 PM) are prepared for the immediate next scheduled delivery day. Orders received after the cutoff time will automatically roll over to the subsequent delivery date shown in your app dashboard.',
      ),
      PolicySection(
        heading: '5. Contactless & Doorstep Delivery Protocol',
        content: 'Our delivery executives deliver directly to your registered doorstep. If you are unavailable, you may specify a safe drop-off location (e.g. security gate or neighbor) via support.',
      ),
    ],
  );

  // 5. Account Deletion Policy
  static const PolicyItem accountDeletionPolicy = PolicyItem(
    id: 'account_deletion_policy',
    title: 'Account Deletion Policy',
    marathiTitle: 'खाते हटवण्याचे धोरण',
    summary: 'Complete disclosure of online app account deletion, data purge, and store record retention.',
    icon: Icons.no_accounts_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Right to Delete Your Online Account',
        content: 'In accordance with Google Play Store User Data Policies and applicable privacy regulations, you have the right to delete your OrderKart online account and associated credentials at any time.',
      ),
      PolicySection(
        heading: '2. How to Request Account Deletion',
        content: 'You can delete your account directly from within the app in two simple steps:',
        bulletPoints: [
          'Open the OrderKart app > Navigate to "My Profile" tab.',
          'Scroll to the bottom of the page > Tap "Delete Account" (marked in red).',
          'Review the confirmation modal > Tap "Yes, Delete Account".',
        ],
      ),
      PolicySection(
        heading: '3. What Data is Deleted Immediately',
        content: 'Upon confirming account deletion, the following data is immediately and permanently purged from our cloud servers:',
        bulletPoints: [
          'Your online authentication credentials, passwords, and hashed PINs.',
          'Your active login sessions and cached authentication tokens.',
          'Your Firebase Cloud Messaging (FCM) push notification registration token.',
          'Local cached user profile data on your device.',
        ],
      ),
      PolicySection(
        heading: '4. What Data is Retained & Why',
        content: 'Please note the distinction between your online app login and physical store ledger records:',
        bulletPoints: [
          'Offline Store Ledger & Tax Invoices: Past completed order records, billing receipts, and ledger balances are retained in the shop\'s local OrderKart management system for legal compliance, tax accounting, and auditing under Indian commercial laws.',
          'No Online Access: You will no longer be able to log in to the mobile application until you request a new code setup from the store administration.',
        ],
      ),
      PolicySection(
        heading: '5. Alternative Deletion Method (Web / Email)',
        content: 'If you have uninstalled the app and wish to delete your account remotely, send an email to supportorderkart@gmail.com or message us on WhatsApp (+91 90211 07009) with your registered mobile number and Member Code. Your online account will be purged within 48 hours.',
      ),
    ],
  );

  // 6. Pricing & Price Change Policy
  static const PolicyItem pricingPolicy = PolicyItem(
    id: 'pricing_policy',
    title: 'Pricing & Price Change Policy',
    marathiTitle: 'किंमत व दर बदल धोरण',
    summary: 'Daily market rate updates, smart ceiling rounding rules, and unit pricing explanations.',
    icon: Icons.price_change_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Dynamic Daily Wholesale Rates',
        content: 'Prices of fresh vegetables and fruits fluctuate daily based on APMC (Agriculture Produce Market Committee) wholesale auctions and crop seasonality. We update our catalog prices daily to pass on maximum market savings to you.',
      ),
      PolicySection(
        heading: '2. 5-Rupee Smart Ceiling Rounding Rule',
        content: 'To simplify cash transactions and eliminate loose coin hassles upon delivery, OrderKart implements a 5-rupee ceiling rounding rule on order subtotals:',
        bulletPoints: [
          'Any calculated total ending in a non-5 digit is rounded up to the nearest ₹5 ceiling (e.g. ₹142 -> ₹145, ₹188 -> ₹190).',
          'The rounded total is displayed transparently in your cart, checkout summary, and order confirmation receipt before placing the order.',
        ],
      ),
      PolicySection(
        heading: '3. Price Lock Guarantee on Order Placement',
        content: 'The price you see at the moment you confirm your order is your locked price. If catalog prices increase between the time you place your order and delivery arrival, you will only pay the price recorded at checkout.',
      ),
      PolicySection(
        heading: '4. Weight & Unit Measurements',
        content: 'Items are priced according to standard metric units: per Kilogram (kg), 500 grams (g), 250 grams, Dozen (doz), or Piece (pcs). All fractional unit calculations are computed precisely with zero hidden surcharges.',
      ),
      PolicySection(
        heading: '5. Calculation Review & Error Reporting',
        content: 'Because the application is continuously updated, users are encouraged to verify their subtotal, rounding adjustments, and final bill amount on the checkout screen before order placement. If an evident calculation or display error is noticed, please report it to our customer support team (+91 90211 07009) so that we may review and address the issue.',
      ),
    ],
  );

  // 7. Contact, Support & Grievance Policy
  static const PolicyItem grievancePolicy = PolicyItem(
    id: 'grievance_policy',
    title: 'Contact, Support & Grievance Policy',
    marathiTitle: 'संपर्क व तक्रार निवारण धोरण',
    summary: 'Direct store customer support channels, Grievance Officer details, and escalation matrix.',
    icon: Icons.headset_mic_outlined,
    effectiveDate: effectiveDate,
    lastUpdated: lastUpdatedDate,
    sections: [
      PolicySection(
        heading: '1. Customer Care & Support Channels',
        content: 'Our team is available to assist you with order placements, delivery inquiries, payment questions, and feedback:',
        bulletPoints: [
          'WhatsApp Support: +91 90211 07009 (Fastest response)',
          'Phone Helpline: +91 90211 07009',
          'Support Email: supportorderkart@gmail.com',
          'Support Operating Hours: 7:00 AM – 9:00 PM IST (All 7 days a week)',
        ],
      ),
      PolicySection(
        heading: '2. Statutory Grievance Redressal Mechanism',
        content: 'In accordance with the Information Technology Act 2000, IT Rules 2021, and Consumer Protection (E-Commerce) Rules 2020, OrderKart has designated a Grievance Officer for consumer dispute resolution:',
        bulletPoints: [
          'Designation: Grievance Redressal Officer',
          'Entity: OrderKart Fresh Foods & Essentials',
          'Address: Market Yard, Yavatmal, Maharashtra 445001, India',
          'Email: grievance@aplibhaji.com (or supportorderkart@gmail.com)',
          'Phone: +91 90211 07009',
        ],
      ),
      PolicySection(
        heading: '3. Grievance Escalation & Timelines',
        content: 'We adhere to the following statutory resolution standards:',
        bulletPoints: [
          'Acknowledgment: Grievances received via email or official channels are acknowledged within 24 to 48 hours with a unique tracking ticket.',
          'Resolution Timeline: All complaints and quality disputes are investigated and redressed within a maximum of 15 business days from the receipt date.',
        ],
      ),
    ],
  );
}
