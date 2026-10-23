"""Phrase banks for the synthetic data. Every name, email and address is fictional.
Emails use example.com and IPs use the documentation ranges (RFC 5737)."""

TICKET_CATEGORIES = {
    "billing": [
        "I was charged twice for order {order}.",
        "My invoice for {order} shows a fee I never agreed to.",
        "The refund for {order} has not reached my card after two weeks.",
        "Why did my subscription renew at a higher price this month?",
        "My card was declined at checkout but the money left my account.",
        "Please explain the extra tax line on order {order}.",
    ],
    "shipping": [
        "Order {order} says delivered but nothing arrived.",
        "The tracking number for {order} has not updated in six days.",
        "My package went to my old address even though I changed it.",
        "The courier left order {order} in the rain and the box is soaked.",
        "Can you tell me when order {order} will actually ship?",
        "Only half of order {order} arrived. Where is the rest?",
    ],
    "product_defect": [
        "The {product} I bought stopped working after three days.",
        "The zipper on my {product} broke the first time I used it.",
        "My {product} arrived with a cracked case.",
        "The battery in the {product} drains in under an hour.",
        "The {product} makes a loud grinding noise when it starts.",
        "Two buttons on the {product} do nothing at all.",
    ],
    "account_access": [
        "I can't log in. The reset email never arrives.",
        "My account is locked after one wrong password.",
        "Two-factor codes stopped working on my phone.",
        "Someone changed my account email and I can't sign in.",
        "The app logs me out every few minutes.",
        "I can't find where to change my password.",
    ],
    "returns": [
        "I want to return the {product} from order {order}.",
        "How do I get a return label for order {order}?",
        "The return window closed one day early. Can you extend it?",
        "I sent the {product} back last week. Did you receive it?",
        "Can I exchange the {product} for a different size?",
        "Your site won't let me start a return for order {order}.",
    ],
    "safety": [
        "The {product} got very hot and smelled like burning plastic.",
        "Sparks came out of the charger for my {product}.",
        "My child cut a finger on a sharp edge of the {product}.",
        "The {product} started smoking while it charged overnight.",
        "A part of the {product} snapped off and flew across the room.",
        "The {product} gave me a small electric shock.",
    ],
}

OPENERS = ["Hi,", "Hello team,", "Hey,", "Good morning,", "", "Hi there,", "To whom it may concern,"]
CLOSERS = ["Thanks.", "Please help.", "This is urgent.", "Waiting for a reply.", "", "Regards.", "Fix this please."]
DETAILS = [
    "I already tried the help page.",
    "This is the second time this month.",
    "I have been a customer for years.",
    "Your chat bot could not help.",
    "",
    "I need this sorted before the weekend.",
    "My order number is above.",
]

PRODUCTS = [
    "TrailLite headlamp", "AeroBlend blender", "Nimbus rain jacket", "Volt power bank",
    "Summit hiking boots", "Echo smart speaker", "Glide office chair", "Pulse fitness band",
    "Harbor coffee grinder", "Orbit desk lamp",
]

# 50 products for reviews, each with one planted top complaint.
REVIEW_PRODUCTS = [f"Model {c}{n}" for c in "ABCDE" for n in range(1, 11)]
COMPLAINTS = [
    ("battery", "the battery dies far too fast"),
    ("fit", "the sizing runs two sizes small"),
    ("noise", "it is much louder than advertised"),
    ("instructions", "the instructions are impossible to follow"),
    ("durability", "it fell apart within a month"),
    ("smell", "it has a strong chemical smell"),
    ("app", "the companion app keeps crashing"),
    ("delivery_damage", "it always arrives scratched or dented"),
    ("missing_parts", "screws and parts are missing from the box"),
    ("overheating", "it gets too hot to touch"),
]
PRAISE = [
    "works exactly as described", "great value for the price", "setup took two minutes",
    "looks better than the photos", "the build quality is solid", "customer support was quick",
]
POS_TEMPLATES = ["Love it, {p}.", "Five stars, {p}.", "Really happy, {p}.", "Excellent purchase, {p}."]
NEG_TEMPLATES = ["Disappointed, {c}.", "Would not buy again, {c}.", "Returning it, {c}.", "Terrible, {c}."]
MIXED_TEMPLATES = ["Mostly fine, {p}, but {c}.", "It {p2} but {c}.", "Good start, then {c}."]

FIRST = ["Alicia", "Marcus", "Priya", "Tom", "Sofia", "Daniel", "Grace", "Omar", "Lena", "Victor",
         "Hannah", "Jorge", "Mei", "Samuel", "Ruth", "Ethan", "Nadia", "Felix", "Irene", "Kwame"]
LAST = ["Delgado", "Whitfield", "Raman", "Kowalski", "Brennan", "Okafor", "Lindqvist", "Moreau",
        "Haddad", "Castellano", "Pemberton", "Nakamura", "Ferreira", "Sullivan", "Abernathy"]
STREETS = ["Maple Avenue", "Harbor Road", "Juniper Lane", "Cedar Street", "Lakeview Drive", "Orchard Way"]
CITIES = [("Portland", "OR", "97201"), ("Austin", "TX", "78701"), ("Denver", "CO", "80202"),
          ("Columbus", "OH", "43215"), ("Raleigh", "NC", "27601"), ("Madison", "WI", "53703")]

NOTE_CLEAN = [
    "Customer asked about the loyalty program tiers.",
    "Called about delivery windows for the holiday period.",
    "Wants to upgrade to the annual plan next month.",
    "Asked whether the warranty covers accidental damage.",
    "Follow up next week on the bulk order discount.",
    "Requested a copy of the last three invoices.",
    "Interested in the new product line, send the catalog.",
]
NOTE_PII = [
    "Spoke with {name}. Call back on {phone} after 3pm.",
    "{name} asked to send the contract to {email}.",
    "Ship the replacement to {address}. Contact {name} if it fails.",
    "{name} confirmed the new phone number {phone} and email {email}.",
    "Customer {name} moved to {address}. Update the billing record.",
]

LOG_ROUTINE = [
    "INFO user {user} logged in from {ip}",
    "INFO GET /api/orders/{n} 200 {ms}ms",
    "INFO scheduled job nightly_export finished in {s}s",
    "INFO cache warmed for region us-west",
    "INFO user {user} updated profile settings",
    "INFO POST /api/cart 201 {ms}ms",
]
LOG_ERROR = [
    "ERROR payment gateway timeout after {ms}ms for order {n}",
    "ERROR disk usage at 91 percent on worker-{w}",
    "WARN retrying connection to inventory service (attempt {a})",
    "ERROR null pointer in checkout handler, request {n}",
    "WARN slow query on orders table took {s}s",
]
LOG_INCIDENT = [
    "WARN {k} failed logins for user admin from {ip} in 60s",
    "INFO user {user} downloaded 48,000 customer records to an external drive",
    "WARN new API key created for service account at 03:12 from {ip}",
    "INFO user {user} granted ACCOUNTADMIN to new user temp_{n}",
    "WARN login for user {user} from {ip} 9 minutes after a login from another continent",
    "INFO firewall rule allowing 0.0.0.0/0 added to database port by {user}",
]

TRANSLATIONS = {
    "es": [
        ("Me cobraron dos veces el pedido {order}.", "billing"),
        ("El pedido {order} figura como entregado pero no llegó nada.", "shipping"),
        ("El {product} dejó de funcionar a los tres días.", "product_defect"),
        ("No puedo iniciar sesión, el correo de restablecimiento nunca llega.", "account_access"),
        ("Quiero devolver el {product} del pedido {order}.", "returns"),
        ("El {product} se calentó mucho y olía a plástico quemado.", "safety"),
    ],
    "de": [
        ("Mir wurde die Bestellung {order} doppelt berechnet.", "billing"),
        ("Bestellung {order} gilt als zugestellt, aber nichts ist angekommen.", "shipping"),
        ("Der {product} funktionierte nach drei Tagen nicht mehr.", "product_defect"),
        ("Ich kann mich nicht anmelden, die E-Mail zum Zurücksetzen kommt nie an.", "account_access"),
        ("Ich möchte den {product} aus Bestellung {order} zurückgeben.", "returns"),
        ("Der {product} wurde sehr heiß und roch nach verbranntem Plastik.", "safety"),
    ],
    "fr": [
        ("On m'a facturé deux fois la commande {order}.", "billing"),
        ("La commande {order} est indiquée comme livrée mais rien n'est arrivé.", "shipping"),
        ("Le {product} a cessé de fonctionner au bout de trois jours.", "product_defect"),
        ("Je ne peux pas me connecter, l'e-mail de réinitialisation n'arrive jamais.", "account_access"),
        ("Je veux retourner le {product} de la commande {order}.", "returns"),
        ("Le {product} est devenu très chaud et sentait le plastique brûlé.", "safety"),
    ],
    "pt": [
        ("Fui cobrado duas vezes pelo pedido {order}.", "billing"),
        ("O pedido {order} consta como entregue, mas nada chegou.", "shipping"),
        ("O {product} parou de funcionar depois de três dias.", "product_defect"),
        ("Não consigo entrar, o e-mail de redefinição nunca chega.", "account_access"),
        ("Quero devolver o {product} do pedido {order}.", "returns"),
        ("O {product} esquentou muito e cheirava a plástico queimado.", "safety"),
    ],
    "ja": [
        ("注文{order}で二重に請求されました。", "billing"),
        ("注文{order}は配達済みになっていますが、何も届いていません。", "shipping"),
        ("{product}が3日で動かなくなりました。", "product_defect"),
        ("ログインできません。リセットのメールが届きません。", "account_access"),
        ("注文{order}の{product}を返品したいです。", "returns"),
        ("{product}がとても熱くなり、焦げたプラスチックの臭いがしました。", "safety"),
    ],
}

PRODUCT_FAMILIES = [
    ("headlamp", "LED headlamp for running and camping", ["lumens", "beam", "strap", "rechargeable"]),
    ("blender", "countertop blender for smoothies", ["blades", "jar", "speeds", "ice"]),
    ("rain jacket", "waterproof rain jacket", ["seams", "hood", "breathable", "packable"]),
    ("power bank", "portable power bank", ["mAh", "USB-C", "fast charge", "ports"]),
    ("hiking boots", "waterproof hiking boots", ["ankle", "grip", "laces", "Vibram-style sole"]),
    ("smart speaker", "voice smart speaker", ["microphones", "bass", "Wi-Fi", "assistant"]),
    ("office chair", "ergonomic office chair", ["lumbar", "armrests", "mesh", "recline"]),
    ("fitness band", "fitness tracking band", ["heart rate", "steps", "sleep", "waterproof"]),
    ("coffee grinder", "burr coffee grinder", ["burrs", "grind size", "hopper", "espresso"]),
    ("desk lamp", "adjustable LED desk lamp", ["dimmer", "arm", "color temperature", "base"]),
    ("tent", "two-person backpacking tent", ["poles", "rainfly", "vestibule", "stakes"]),
    ("sleeping bag", "down sleeping bag", ["fill power", "zipper", "hood", "temperature rating"]),
    ("water bottle", "insulated water bottle", ["vacuum", "lid", "stainless", "leakproof"]),
    ("backpack", "daypack backpack", ["liters", "hip belt", "laptop sleeve", "pockets"]),
    ("headphones", "noise cancelling headphones", ["drivers", "ANC", "ear cups", "battery"]),
    ("keyboard", "mechanical keyboard", ["switches", "keycaps", "backlight", "layout"]),
    ("air fryer", "air fryer", ["basket", "presets", "quarts", "nonstick"]),
    ("yoga mat", "non-slip yoga mat", ["thickness", "grip", "foam", "strap"]),
    ("bike light", "rechargeable bike light", ["mount", "flash mode", "visibility", "lumens"]),
    ("vacuum", "cordless stick vacuum", ["suction", "dustbin", "filter", "runtime"]),
]
ADJ = ["lightweight", "compact", "durable", "premium", "budget", "pro", "everyday", "travel", "heavy-duty", "slim"]

CALL_SCRIPTS = [
    ("resolved", "positive",
     "Thanks for calling, how can I help? My order {order} arrived damaged. I'm sorry about that. "
     "I'll send a replacement today with free express shipping. That's great, thank you so much. "
     "You're welcome, the replacement arrives Thursday."),
    ("refund", "positive",
     "Support, this is Sam. I returned the {product} two weeks ago and I'm still waiting. "
     "I see the return. I've issued the refund now, it shows in three to five days. "
     "Perfect, I appreciate the quick help."),
    ("escalated", "negative",
     "Hello, how can I help? This is the third time I'm calling about order {order}. "
     "I understand. I can't fix it from here, so I'm escalating to a supervisor. "
     "This is ridiculous, I've wasted hours on this. I'm sorry, a supervisor will call you tomorrow."),
    ("cancelled", "negative",
     "Thanks for calling. I want to cancel my subscription, the price went up again. "
     "I can offer a discount for three months. No, I'm done, please cancel it now. "
     "Okay, the subscription is cancelled. I'm sorry to see you go."),
]
