import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 14)],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Text(
                      'AL MOBARMG',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0A0F2E)),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.storefront_rounded),
                      label: Text('تطبيقاتنا — App Store', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 52),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF0A0F2E), Color(0xFF1B2B8B), Color(0xFF0D2060)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: const Color(0x262196D3),
                          border: Border.all(color: const Color(0x662196D3)),
                        ),
                        child: Text('متاحون لمشاريع جديدة الآن', style: GoogleFonts.cairo(color: const Color(0xFF7DD8FF), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'نحوّل فكرتك إلى تطبيق حقيقي',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: isMobile ? 35 : 52, fontWeight: FontWeight.w900, height: 1.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'AL MOBARMG — We Build Real Apps',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.sora(color: Colors.white54, fontSize: isMobile ? 18 : 26, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'نطور تطبيقات موبايل Android & iOS ومواقع ويب احترافية للشركات وأصحاب المشاريع. تسليم سريع، جودة عالية، دعم مستمر بعد الإطلاق.',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 17, height: 1.8),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2196D3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.go('/home'),
                            child: Text('ادخل متجر التطبيقات', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.go('/login'),
                            child: Text('تسجيل الدخول', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
