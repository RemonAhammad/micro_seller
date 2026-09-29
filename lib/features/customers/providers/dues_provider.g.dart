// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dues_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every customer who owes money, computed live from orders. Re-emits
/// whenever orders, customers or payments change.

@ProviderFor(dues)
final duesProvider = DuesProvider._();

/// Every customer who owes money, computed live from orders. Re-emits
/// whenever orders, customers or payments change.

final class DuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomerDue>>,
          List<CustomerDue>,
          Stream<List<CustomerDue>>
        >
    with
        $FutureModifier<List<CustomerDue>>,
        $StreamProvider<List<CustomerDue>> {
  /// Every customer who owes money, computed live from orders. Re-emits
  /// whenever orders, customers or payments change.
  DuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomerDue>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomerDue>> create(Ref ref) {
    return dues(ref);
  }
}

String _$duesHash() => r'6f5e6be2dfbde91d85594ab728269995d8260371';

/// A customer's payment history, newest first.

@ProviderFor(customerPayments)
final customerPaymentsProvider = CustomerPaymentsFamily._();

/// A customer's payment history, newest first.

final class CustomerPaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Payment>>,
          List<Payment>,
          Stream<List<Payment>>
        >
    with $FutureModifier<List<Payment>>, $StreamProvider<List<Payment>> {
  /// A customer's payment history, newest first.
  CustomerPaymentsProvider._({
    required CustomerPaymentsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customerPaymentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerPaymentsHash();

  @override
  String toString() {
    return r'customerPaymentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Payment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Payment>> create(Ref ref) {
    final argument = this.argument as int;
    return customerPayments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerPaymentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerPaymentsHash() => r'181d0f32202364f376f693939235558922da1ab1';

/// A customer's payment history, newest first.

final class CustomerPaymentsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Payment>>, int> {
  CustomerPaymentsFamily._()
    : super(
        retry: null,
        name: r'customerPaymentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A customer's payment history, newest first.

  CustomerPaymentsProvider call(int customerId) =>
      CustomerPaymentsProvider._(argument: customerId, from: this);

  @override
  String toString() => r'customerPaymentsProvider';
}
