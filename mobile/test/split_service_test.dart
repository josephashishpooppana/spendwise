import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';

void main() {
  test('equal split divides among me plus contacts', () {
    final shares = SplitService.equalContactShares(
      totalAmount: 100,
      contactIds: ['c1'],
    );
    expect(shares['c1'], 50);
    expect(
      SplitService.myEqualShare(totalAmount: 100, contactIds: ['c1']),
      50,
    );
  });

  test('custom split assigns remainder to last participant', () {
    final amounts = SplitService.customAmountsWithRemainder(
      totalAmount: 100,
      participantIds: [SplitService.selfParticipantId, 'c1'],
      enteredAmounts: {SplitService.selfParticipantId: 20},
    );
    expect(amounts[SplitService.selfParticipantId], 20);
    expect(amounts['c1'], 80);
    expect(
      SplitService.customTotalsMatch(totalAmount: 100, amounts: amounts),
      isTrue,
    );
  });

  test('custom split with three people', () {
    final amounts = SplitService.customAmountsWithRemainder(
      totalAmount: 100,
      participantIds: [
        SplitService.selfParticipantId,
        'c1',
        'c2',
      ],
      enteredAmounts: {
        SplitService.selfParticipantId: 20,
        'c1': 30,
      },
    );
    expect(amounts['c2'], 50);
  });
}
