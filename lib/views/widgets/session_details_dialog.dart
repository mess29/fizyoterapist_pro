import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';

class SessionDetailsDialog extends StatefulWidget {
  final Session session;

  const SessionDetailsDialog({super.key, required this.session});

  @override
  State<SessionDetailsDialog> createState() => _SessionDetailsDialogState();
}

class _SessionDetailsDialogState extends State<SessionDetailsDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late PaymentStatus _paymentStatus;
  late TextEditingController _priceController;
  late TextEditingController _amountPaidController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.session.dateTime);
    _paymentStatus = widget.session.paymentStatus;
    _priceController = TextEditingController(
      text: widget.session.price != null ? widget.session.price.toString() : '',
    );
    _amountPaidController = TextEditingController(
      text: widget.session.amountPaid.toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picker = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1), // Indigo 500
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B), // Slate 800
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picker != null) {
      setState(() {
        _selectedDate = picker;
      });
    }
  }

  Future<void> _selectTime() async {
    final picker = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1), // Indigo 500
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B), // Slate 800
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picker != null) {
      setState(() {
        _selectedTime = picker;
      });
    }
  }

  // Quick action toggle between Paid & Unpaid
  void _quickTogglePaidUnpaid() {
    setState(() {
      if (_paymentStatus == PaymentStatus.paid) {
        _paymentStatus = PaymentStatus.unpaid;
        _amountPaidController.text = '0.0';
      } else {
        _paymentStatus = PaymentStatus.paid;
        final double price = double.tryParse(_priceController.text) ?? 0.0;
        _amountPaidController.text = price.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);
    final formattedTime = DateFormat.jm().format(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Session Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Session',
                      onPressed: () => Navigator.of(context).pop('delete'),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  widget.session.label,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8), // Light Blue 400
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(color: Color(0xFF334155), height: 32.0),

                // Reschedule Section
                const Text(
                  'Schedule Info',
                  style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12.0),
                // Date Selector
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF475569)),
                      borderRadius: BorderRadius.circular(10.0),
                      color: const Color(0xFF0F172A),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Color(0xFF6366F1), size: 20.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                // Time Selector
                InkWell(
                  onTap: _selectTime,
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF475569)),
                      borderRadius: BorderRadius.circular(10.0),
                      color: const Color(0xFF0F172A),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF14B8A6), size: 20.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            formattedTime,
                            style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF334155), height: 32.0),

                // Financial Info Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Financial Info',
                      style: TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    // Quick Action Toggle Button
                    OutlinedButton.icon(
                      onPressed: _quickTogglePaidUnpaid,
                      icon: Icon(
                        _paymentStatus == PaymentStatus.paid ? Icons.money_off_rounded : Icons.monetization_on_rounded,
                        size: 14.0,
                        color: _paymentStatus == PaymentStatus.paid ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                      ),
                      label: Text(
                        _paymentStatus == PaymentStatus.paid ? 'Mark Unpaid' : 'Mark Paid',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: _paymentStatus == PaymentStatus.paid ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _paymentStatus == PaymentStatus.paid ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                // Payment Status ChoiceChips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: PaymentStatus.values.map((status) {
                    final isSelected = _paymentStatus == status;
                    Color chipColor;
                    switch (status) {
                      case PaymentStatus.paid:
                        chipColor = const Color(0xFF22C55E); // Green
                        break;
                      case PaymentStatus.unpaid:
                        chipColor = const Color(0xFFEF4444); // Red
                        break;
                      case PaymentStatus.partiallyPaid:
                        chipColor = const Color(0xFFF59E0B); // Amber
                        break;
                    }

                    return ChoiceChip(
                      label: Text(
                        status.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 12.0,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: chipColor.withOpacity(0.8),
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _paymentStatus = status;
                            // Helper autofill logics
                            if (status == PaymentStatus.paid) {
                              final price = double.tryParse(_priceController.text) ?? 0.0;
                              _amountPaidController.text = price.toString();
                            } else if (status == PaymentStatus.unpaid) {
                              _amountPaidController.text = '0.0';
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16.0),
                // Price & Amount Paid Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                          prefixText: r'$ ',
                          prefixStyle: const TextStyle(color: Color(0xFF64748B)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF475569)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF6366F1)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                        ),
                        onChanged: (val) {
                          // If paid, auto-update amount paid
                          if (_paymentStatus == PaymentStatus.paid) {
                            final price = double.tryParse(val) ?? 0.0;
                            _amountPaidController.text = price.toString();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: TextFormField(
                        controller: _amountPaidController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount Paid',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                          prefixText: r'$ ',
                          prefixStyle: const TextStyle(color: Color(0xFF64748B)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF475569)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF6366F1)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                        onChanged: (val) {
                          // Dynamically set status if they tweak amount paid manually
                          final price = double.tryParse(_priceController.text) ?? 0.0;
                          final paid = double.tryParse(val) ?? 0.0;
                          setState(() {
                            if (paid == 0) {
                              _paymentStatus = PaymentStatus.unpaid;
                            } else if (paid >= price && price > 0) {
                              _paymentStatus = PaymentStatus.paid;
                            } else {
                              _paymentStatus = PaymentStatus.partiallyPaid;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32.0),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final double? price = _priceController.text.trim().isNotEmpty
                              ? double.parse(_priceController.text)
                              : null;
                          final double amountPaid = double.parse(_amountPaidController.text);
                          
                          final combinedDateTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _selectedTime.hour,
                            _selectedTime.minute,
                          );

                          final updated = widget.session.copyWith(
                            price: price,
                            paymentStatus: _paymentStatus,
                            amountPaid: amountPaid,
                            dateTime: combinedDateTime,
                          );

                          Navigator.of(context).pop(updated);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1), // Indigo 500
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
