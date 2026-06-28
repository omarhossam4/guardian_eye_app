class CreateGuardianProfileRequest {
  const CreateGuardianProfileRequest({
    required this.name,
    this.phoneNumber="01026400332",
  });

  final String name;
  final String? phoneNumber;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (phoneNumber != null && phoneNumber!.isNotEmpty) 'phone': phoneNumber,
    };
  }
}
